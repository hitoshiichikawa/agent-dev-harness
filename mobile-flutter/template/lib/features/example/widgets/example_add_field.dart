import 'package:flutter/material.dart';

class ExampleAddField extends StatefulWidget {
  const ExampleAddField({required this.onSubmit, super.key});
  final ValueChanged<String> onSubmit;

  @override
  State<ExampleAddField> createState() => _ExampleAddFieldState();
}

/// 純粋な UI 状態（入力中テキスト）だけ setState でよい。
class _ExampleAddFieldState extends State<ExampleAddField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'name', border: OutlineInputBorder()),
        onSubmitted: (v) {
          widget.onSubmit(v);
          _controller.clear();
        },
      ),
    );
  }
}
