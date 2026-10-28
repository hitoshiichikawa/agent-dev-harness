/** access はメモリ、refresh は httpOnly cookie か secure storage。SPA では localStorage に access を置かない。 */
let accessToken: string | null = null;

export const getAccessToken = () => accessToken;
export const setAccessToken = (t: string | null) => {
  accessToken = t;
};

export async function refreshAccessToken(): Promise<string | null> {
  const refresh = sessionStorage.getItem("refreshToken"); // 雛形。本番は httpOnly cookie に寄せる
  if (!refresh) return null;
  const res = await fetch(`${import.meta.env.VITE_API_BASE ?? "/api"}/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: refresh }),
  });
  if (!res.ok) {
    setAccessToken(null);
    return null;
  }
  const pair = (await res.json()) as { accessToken: string; refreshToken: string };
  setAccessToken(pair.accessToken);
  sessionStorage.setItem("refreshToken", pair.refreshToken);
  return pair.accessToken;
}
