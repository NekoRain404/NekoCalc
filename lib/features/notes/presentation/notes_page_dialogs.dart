part of 'notes_page.dart';

class _ClipboardImportDialog extends StatelessWidget {
  const _ClipboardImportDialog({required this.plan});

  final NotesClipboardImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final previews = plan.previews;
    final previewDrafts = previews.take(5).toList(growable: false);
    final hiddenCount = plan.totalCount - previewDrafts.length;
    return AlertDialog(
      title: const Text('从剪贴板导入'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.summary),
            const SizedBox(height: 12),
            ...previewDrafts.map(
              (draft) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_sourceIcon(draft.source)),
                title: Text(draft.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: draft.description.isEmpty
                    ? null
                    : Text(draft.description,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (hiddenCount > 0)
              Text('还有 $hiddenCount 条未显示',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入')),
      ],
    );
  }

  IconData _sourceIcon(NotesImportSource source) {
    return switch (source) {
      NotesImportSource.note => Icons.article_outlined,
      NotesImportSource.history => Icons.schedule,
      NotesImportSource.plainText => Icons.content_paste_outlined,
    };
  }
}

class _NoteDraft {
  const _NoteDraft({
    required this.title,
    required this.description,
    required this.body,
    required this.tags,
  });

  final String title;
  final String description;
  final String body;
  final List<String> tags;
}

class _NoteFilterDraft {
  const _NoteFilterDraft({
    required this.archiveFilter,
    required this.sort,
    required this.tag,
  });

  final NoteArchiveFilter archiveFilter;
  final NoteSort sort;
  final String? tag;
}

class _NoteFilterSheet extends StatefulWidget {
  const _NoteFilterSheet({
    required this.archiveFilter,
    required this.sort,
    required this.tag,
    required this.availableTags,
  });

  final NoteArchiveFilter archiveFilter;
  final NoteSort sort;
  final String? tag;
  final List<String> availableTags;

  @override
  State<_NoteFilterSheet> createState() => _NoteFilterSheetState();
}

class _NoteFilterSheetState extends State<_NoteFilterSheet> {
  late NoteArchiveFilter _archiveFilter;
  late NoteSort _sort;
  late String? _tag;

  @override
  void initState() {
    super.initState();
    _archiveFilter = widget.archiveFilter;
    _sort = widget.sort;
    _tag = widget.tag;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('笔记筛选',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            DropdownButtonFormField<NoteArchiveFilter>(
              initialValue: _archiveFilter,
              decoration: const InputDecoration(labelText: '状态'),
              items: const [
                DropdownMenuItem(
                    value: NoteArchiveFilter.active, child: Text('未归档')),
                DropdownMenuItem(
                    value: NoteArchiveFilter.archived, child: Text('已归档')),
                DropdownMenuItem(
                    value: NoteArchiveFilter.all, child: Text('全部状态')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _archiveFilter = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<NoteSort>(
              initialValue: _sort,
              decoration: const InputDecoration(labelText: '排序'),
              items: const [
                DropdownMenuItem(
                    value: NoteSort.updatedNewest, child: Text('最近更新')),
                DropdownMenuItem(
                    value: NoteSort.updatedOldest, child: Text('最早更新')),
                DropdownMenuItem(
                    value: NoteSort.titleAscending, child: Text('标题 A-Z')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
            if (widget.availableTags.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('标签'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('全部标签'),
                    selected: _tag == null,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                  ...widget.availableTags.map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: _tag == tag,
                      onSelected: (_) => setState(() => _tag = tag),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _NoteFilterDraft(
                    archiveFilter: _archiveFilter,
                    sort: _sort,
                    tag: _tag,
                  ),
                ),
                child: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');
    _bodyController = TextEditingController(text: widget.item?.body ?? '');
    _tagsController = TextEditingController(
      text: widget.item?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
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
              const SizedBox(height: 10),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '用逗号分隔，例如：实验, 待处理',
                ),
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
              tags: _tagsController.text.split(RegExp(r'[,，\n]')),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
