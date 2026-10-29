import '../l10n/system_messages.dart';
import '../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ai_catalog.dart';

class AiBrandIcon extends StatelessWidget {
  const AiBrandIcon(this.brand, {super.key});
  final String? brand;
  @override
  Widget build(BuildContext context) => brand == null
      ? Icon(LucideIcons.messageSquare, size: 24)
      : SvgPicture.asset(
          'assets/ai-icons/$brand.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
}

Future<AiCatalogModel?> chooseAiModel(
  BuildContext context,
  List<AiCatalogModel> models,
) => showModalBottomSheet<AiCatalogModel>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AiModelPicker(models: models),
);

class AiModelPicker extends StatefulWidget {
  const AiModelPicker({super.key, required this.models});
  final List<AiCatalogModel> models;
  @override
  State<AiModelPicker> createState() => _AiModelPickerState();
}

class _AiModelPickerState extends State<AiModelPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final models = widget.models
        .where(
          (m) =>
              '${m.label} ${m.id}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Text(tr(context).chooseModel, style: TextStyle(fontSize: 20)),
            SizedBox(height: 12),
            TextField(
              autocorrect: false,
              decoration: InputDecoration(
                labelText: tr(context).searchModelNameOrId,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            SizedBox(height: 8),
            Expanded(
              child: models.isEmpty
                  ? Center(
                      child: Text(tr(context).noMatchingModelYouCanStillEnter),
                    )
                  : ListView.builder(
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        final model = models[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                          leading: AiBrandIcon(model.brand),
                          title: Text(
                            systemMessage(context, model.label) ?? model.label,
                          ),
                          subtitle: Text(
                            '${model.id}\n${model.textChat == true ? tr(context).listedAsTextCapableCompatibilityNeedsTesting : tr(context).compatibilityUnverified}',
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.pop(context, model),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef AiLinkOpener = Future<bool> Function(Uri uri);
Future<bool> openAiOfficialLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
Future<void> showAiOfficialLink(
  BuildContext context,
  String address,
  AiLinkOpener opener,
) async {
  var opened = false;
  try {
    opened = await opener(Uri.parse(address));
  } catch (_) {
    /* No raw platform errors or secrets in logs. */
  }
  if (opened || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context).cannotOpenTheSystemBrowser),
      content: SelectableText(
        tr(context).copyThisLinkAndOpenItManually((address).toString()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context).close),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(tr(context).copyLink),
        ),
      ],
    ),
  );
}
