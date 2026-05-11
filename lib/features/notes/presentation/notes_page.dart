import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../data/models/history_item.dart';
import '../../../data/models/note_item.dart';
import '../../../shared/presentation/app_chrome.dart';

enum NotesTab { all, notes, history, formulas, tools }

class NotesPage extends StatefulWidget {
  const NotesPage({required this.db, super.key});

  final AppDatabase db;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late Future<List<NoteItem>> _notes;
  late Future<List<HistoryItem>> _history;
  NotesTab _tab = NotesTab.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _notes = widget.db.notes();
    _history = widget.db.history();
  }

  Future<void> _addNoteDialog() async {
    await _showNoteDialog();
  }

  Future<void> _showNoteDialog({NoteItem? item}) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    titleController.text = item?.title ?? '';
    bodyController.text = item?.body ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '新增笔记' : '编辑笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '标题')),
            const SizedBox(height: 10),
            TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '内容')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (saved == true) {
      final title = titleController.text.trim().isEmpty ? '未命名笔记' : titleController.text.trim();
      final body = bodyController.text.trim();
      if (item == null) {
        await widget.db.addNote(title, body);
      } else {
        await widget.db.updateNote(id: item.id, title: title, body: body);
      }
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(child: PageTitle('笔记')),
            IconToolButton(icon: Icons.delete_sweep_outlined, tooltip: '清空历史', onTap: _clearHistory),
            const SizedBox(width: 8),
            IconToolButton(icon: Icons.add, tooltip: '新增笔记', onTap: _addNoteDialog),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(hintText: '搜索笔记、历史、公式...', prefixIcon: Icon(Icons.search)),
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
        if (_tab == NotesTab.all || _tab == NotesTab.history) ...[
          const SectionTitle('计算历史'),
          _historySection(),
          const SizedBox(height: 14),
        ],
        if (_tab != NotesTab.history) ...[
          const SectionTitle('个人笔记'),
          _notesSection(),
        ],
      ],
    );
  }

  Widget _tabPill(NotesTab tab, String label) {
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: TabPill(label: label, selected: _tab == tab),
    );
  }

  Widget _historySection() {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<HistoryItem>>(
      future: _history,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? []).where(_matchesHistory).toList();
        if (items.isEmpty) return const EmptyPanel('暂无匹配的历史记录。');
        return Column(
          children: items
              .map((item) => Card(
                    child: ListTile(
                      onTap: () => _showHistoryActions(item),
                      leading: Icon(Icons.schedule, color: scheme.primary),
                      title: Text(item.expression, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(item.result, style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () async {
                              await widget.db.deleteHistory(item.id);
                              setState(_reload);
                            },
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _notesSection() {
    return FutureBuilder<List<NoteItem>>(
      future: _notes,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? []).where(_matchesNote).toList();
        if (items.isEmpty) return const EmptyPanel('暂无匹配的笔记。');
        return Column(
          children: items
              .map((item) => Card(
                    child: ListTile(
                      onTap: () => _showNoteDialog(item: item),
                      leading: Icon(_noteIcon(item), color: const Color(0xFF23B45D)),
                      title: Text(item.title),
                      subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: '删除',
                        onPressed: () async {
                          await widget.db.deleteNote(item.id);
                          setState(_reload);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  bool _matchesHistory(HistoryItem item) {
    if (_query.isNotEmpty && !'${item.expression}${item.result}'.contains(_query)) return false;
    if (_tab == NotesTab.tools) return item.expression.contains('=') || item.result.contains(':');
    if (_tab == NotesTab.formulas) return item.expression.contains('sin') || item.expression.contains('sqrt') || item.expression.contains('公式');
    return true;
  }

  bool _matchesNote(NoteItem item) {
    if (_query.isNotEmpty && !'${item.title}${item.body}'.contains(_query)) return false;
    if (_tab == NotesTab.tools) return item.body.contains('公式：') || item.title.contains('计算');
    if (_tab == NotesTab.formulas) return item.title.contains('公式') || item.body.contains('=');
    return true;
  }

  IconData _noteIcon(NoteItem item) {
    if (item.title.contains('公式') || item.body.contains('=')) return Icons.functions;
    if (item.body.contains('公式：')) return Icons.construction;
    return Icons.article_outlined;
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确认删除全部计算历史？笔记不会受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.db.clearHistory();
    setState(_reload);
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
      await Clipboard.setData(ClipboardData(text: '${item.expression} = ${item.result}'));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制历史结果')));
    }
    if (action == 'note') {
      await widget.db.addNote('历史结果', '${item.expression}\n${item.result}');
      setState(_reload);
    }
    if (action == 'delete') {
      await widget.db.deleteHistory(item.id);
      setState(_reload);
    }
  }
}
