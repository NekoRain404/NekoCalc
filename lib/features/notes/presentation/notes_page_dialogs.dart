part of 'notes_page.dart';

class _ClipboardImportDialog extends StatelessWidget {
  const _ClipboardImportDialog({required this.plan});

  final NotesClipboardImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final strings = NotesStrings.of(context);
    // 中文：**这一行的字在画的时候取**（`notes_import_draft_message.dart`）：草稿只带令牌与载荷，
    //       所以对话框一换语言，这一行立刻跟着换——它从不写库，与保存那一侧拿的是同一批格子，
    //       但取表的时刻不同（理由在那些函数的文件头上）。
    // English: **the row's words are fetched at paint time** (`notes_import_draft_message.dart`): a
    //          draft carries only a token and payloads, so changing the language re-words this row at
    //          once — it never reaches the database, and it reads the same cells as the save side, only
    //          at a different moment (the reason is on those functions' file head).
    final previews = plan.previews;
    final previewDrafts = previews.take(5).toList(growable: false);
    final hiddenCount = plan.totalCount - previewDrafts.length;
    return AlertDialog(
      title: Text(strings.clipboardImportTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notesImportPlanSummary(plan, strings)),
            const SizedBox(height: 12),
            ...previewDrafts.map((preview) {
              final description = notesImportPreviewDescription(preview, strings);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_sourceIcon(preview)),
                title: Text(notesImportPreviewTitle(preview, strings),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: description.isEmpty
                    ? null
                    : Text(description,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            }),
            if (hiddenCount > 0)
              Text(strings.hiddenCount(hiddenCount),
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.importButton)),
      ],
    );
  }

  /// 中文：**一行预览前面那个图标。** 判据与迁移前逐字相同：笔记/剪贴板/历史三选一
  ///       （从前由 `NotesImportSource` 回答，现在密封树与措辞令牌一起回答）。
  /// English: **the icon in front of one preview row.** The criterion is character-for-character the
  ///          pre-move one, one of note / clipboard / history (the old `NotesImportSource` answered it;
  ///          the sealed tree and the wording token answer it now).
  IconData _sourceIcon(NotesClipboardImportPreview preview) {
    return switch (preview) {
      NotesNoteImportPreview(:final draft) => switch (draft.wording) {
          NotesNoteDraftWording.parsed => Icons.article_outlined,
          NotesNoteDraftWording.clipboard => Icons.content_paste_outlined,
        },
      NotesHistoryImportPreview() => Icons.schedule,
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
    final strings = NotesStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.noteFilterTitle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            DropdownButtonFormField<NoteArchiveFilter>(
              initialValue: _archiveFilter,
              decoration:
                  InputDecoration(labelText: strings.archiveFilterLabel),
              items: [
                DropdownMenuItem(
                    value: NoteArchiveFilter.active,
                    child: Text(strings.archiveActive)),
                DropdownMenuItem(
                    value: NoteArchiveFilter.archived,
                    child: Text(strings.archiveArchived)),
                DropdownMenuItem(
                    value: NoteArchiveFilter.all,
                    child: Text(strings.archiveAll)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _archiveFilter = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<NoteSort>(
              initialValue: _sort,
              decoration: InputDecoration(labelText: strings.sortLabel),
              items: [
                DropdownMenuItem(
                    value: NoteSort.updatedNewest,
                    child: Text(strings.sortUpdatedNewest)),
                DropdownMenuItem(
                    value: NoteSort.updatedOldest,
                    child: Text(strings.sortUpdatedOldest)),
                DropdownMenuItem(
                    value: NoteSort.titleAscending,
                    child: Text(strings.sortTitleAscending)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
            if (widget.availableTags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(strings.tagLabel),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: Text(strings.allTags),
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
                child: Text(strings.apply),
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
    final strings = NotesStrings.of(context);
    return AlertDialog(
      title: Text(widget.item == null ? strings.newNote : strings.editNote),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: strings.fieldTitle),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: strings.fieldDescription,
                    hintText: strings.fieldDescriptionHint),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(labelText: strings.fieldBody),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: strings.tagLabel,
                  hintText: strings.fieldTagsHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel)),
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
          child: Text(strings.save),
        ),
      ],
    );
  }
}
