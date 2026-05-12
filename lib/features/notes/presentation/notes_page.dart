import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../application/controllers/notes_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/history_item.dart';
import '../../../data/models/note_item.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../shared/presentation/app_chrome.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({required this.db, this.reloadToken = 0, super.key});

  final AppDatabase db;
  final int reloadToken;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotesController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _controller.load();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addNoteDialog() async {
    await _showNoteDialog();
  }

  Future<void> _showNoteDialog({NoteItem? item}) async {
    final draft = await showDialog<_NoteDraft>(
      context: context,
      builder: (context) => _NoteEditorDialog(item: item),
    );
    if (draft == null) return;
    await _controller.saveNote(
      item: item,
      title: draft.title,
      description: draft.description,
      body: draft.body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(child: PageTitle('笔记')),
            IconToolButton(
                icon: Icons.delete_sweep_outlined,
                tooltip: '清空历史',
                onTap: _clearHistory),
            const SizedBox(width: 8),
            IconToolButton(
                icon: Icons.add, tooltip: '新增笔记', onTap: _addNoteDialog),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: _controller.setQuery,
          decoration: const InputDecoration(
              hintText: '搜索笔记、历史、公式...', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabPill(NotesTab.all, '全部'),
              _tabPill(NotesTab.notes, '笔记'),
              _tabPill(NotesTab.history, '历史'),
              _tabPill(NotesTab.formulas, '公式'),
              _tabPill(NotesTab.tools, '工具'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.tab == NotesTab.all ||
            _controller.tab == NotesTab.history) ...[
          const SectionTitle('计算历史'),
          _historySection(),
          const SizedBox(height: 14),
        ],
        if (_controller.tab != NotesTab.history) ...[
          const SectionTitle('个人笔记'),
          _notesSection(),
        ],
      ],
    );
  }

  Widget _tabPill(NotesTab tab, String label) {
    return GestureDetector(
      onTap: () => _controller.setTab(tab),
      child: TabPill(label: label, selected: _controller.tab == tab),
    );
  }

  Widget _historySection() {
    final scheme = Theme.of(context).colorScheme;
    final items = _controller.history;
    if (_controller.loading) return const EmptyPanel('正在加载历史记录。');
    if (_controller.error != null) {
      return EmptyPanel('历史读取失败：${_controller.error}');
    }
    if (items.isEmpty) return const EmptyPanel('暂无匹配的历史记录。');
    return Column(
      children: items
          .map((item) => Card(
                child: ListTile(
                  onTap: () => _showHistoryActions(item),
                  leading: Icon(Icons.schedule, color: scheme.primary),
                  title: Text(item.expression,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.result,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _controller.deleteHistory(item.id),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _notesSection() {
    final items = _controller.notes;
    if (_controller.loading) return const EmptyPanel('正在加载笔记。');
    if (_controller.error != null) {
      return EmptyPanel('笔记读取失败：${_controller.error}');
    }
    if (items.isEmpty) return const EmptyPanel('暂无匹配的笔记。');
    return Column(
      children: items
          .map((item) => Card(
                child: ListTile(
                  onTap: () => _showNoteDialog(item: item),
                  leading:
                      Icon(_noteIcon(item), color: const Color(0xFF23B45D)),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 3),
                          child: Text(item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      Text(item.body,
                          maxLines: item.description.isEmpty ? 2 : 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: '删除',
                    onPressed: () => _controller.deleteNote(item.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ))
          .toList(),
    );
  }

  IconData _noteIcon(NoteItem item) {
    if (item.title.contains('公式') ||
        item.description.contains('公式') ||
        item.body.contains('=')) {
      return Icons.functions;
    }
    if (item.body.contains('公式：') || item.description.contains('工具')) {
      return Icons.construction;
    }
    return Icons.article_outlined;
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确认删除全部计算历史？笔记不会受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (confirm != true) return;
    await _controller.clearHistory();
  }

  Future<void> _showHistoryActions(HistoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制结果'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('保存为笔记'),
              onTap: () => Navigator.pop(context, 'note'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除记录'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      await Clipboard.setData(
          ClipboardData(text: '${item.expression} = ${item.result}'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已复制历史结果')));
      }
    }
    if (action == 'note') {
      await _controller.saveHistoryAsNote(item);
    }
    if (action == 'delete') {
      await _controller.deleteHistory(item.id);
    }
  }
}

class _NoteDraft {
  const _NoteDraft({
    required this.title,
    required this.description,
    required this.body,
  });

  final String title;
  final String description;
  final String body;
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({this.item});

  final NoteItem? item;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');
    _bodyController = TextEditingController(text: widget.item?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '新增笔记' : '编辑笔记'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: '描述', hintText: '写清用途、来源或下一步处理'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: '内容'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NoteDraft(
              title: _titleController.text,
              description: _descriptionController.text,
              body: _bodyController.text,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
