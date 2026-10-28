/** orval の mutator。全 API 呼び出しがここを通る。認証ヘッダと refresh をここで一元化する。 */
import { getAccessToken, refreshAccessToken } from "./auth";

const BASE = import.meta.env.VITE_API_BASE ?? "/api";

export async function fetcher<T>(url: string, init?: RequestInit): Promise<T> {
  const doFetch = async (token: string | null) =>
    fetch(`${BASE}${url}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(init?.headers ?? {}),
      },
    });

  let res = await doFetch(getAccessToken());
  if (res.status === 401) {
    const refreshed = await refreshAccessToken();
    if (refreshed) res = await doFetch(refreshed);
  }
  if (!res.ok) {
    const problem = await res.json().catch(() => ({ title: res.statusText, status: res.status }));
    throw new ApiError(problem);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export class ApiError extends Error {
  constructor(public readonly problem: { title: string; status: number; detail?: string; errors?: { field: string; message: string }[] }) {
    super(problem.detail ?? problem.title);
  }
}
