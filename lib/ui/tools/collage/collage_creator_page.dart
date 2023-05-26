import "package:flutter/material.dart";
import "package:logging/logging.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/file.dart";
import "package:photos/ui/tools/collage/collage_save_button.dart";
import "package:photos/ui/tools/collage/collage_test_grid.dart";
import "package:photos/ui/tools/collage/collage_with_five_items.dart";
import "package:photos/ui/tools/collage/collage_with_four_items.dart";
import "package:photos/ui/tools/collage/collage_with_six_items.dart";
import "package:photos/ui/tools/collage/collage_with_three_items.dart";
import "package:photos/ui/tools/collage/collage_with_two_items.dart";
import "package:widgets_to_image/widgets_to_image.dart";

class CollageCreatorPage extends StatelessWidget {
  static const int collageItemsMin = 2;
  static const int collageItemsMax = 6;

  final _logger = Logger("CreateCollagePage");
  final _widgetsToImageController = WidgetsToImageController();

  final List<File> files;

  CollageCreatorPage(this.files, {super.key});

  @override
  Widget build(BuildContext context) {
    for (final file in files) {
      _logger.info(file.displayName);
    }
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(S.of(context).createCollage),
      ),
      body: _getBody(context),
    );
  }

  Widget _getBody(BuildContext context) {
    final count = files.length;
    Widget collage;
    switch (count) {
      case 2:
        collage = CollageWithTwoItems(
          files[0],
          files[1],
          _widgetsToImageController,
        );
        break;
      case 3:
        collage = CollageWithThreeItems(
          files[0],
          files[1],
          files[2],
          _widgetsToImageController,
        );
        break;
      case 4:
        collage = CollageWithFourItems(
          files[0],
          files[1],
          files[2],
          files[3],
          _widgetsToImageController,
        );
        break;
      case 5:
        collage = CollageWithFiveItems(
          files[0],
          files[1],
          files[2],
          files[3],
          files[4],
          _widgetsToImageController,
        );
        break;
      case 6:
        collage = CollageWithSixItems(
          files[0],
          files[1],
          files[2],
          files[3],
          files[4],
          files[5],
          _widgetsToImageController,
        );
        break;
      default:
        collage = const TestGrid();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            width: 320,
            child: collage,
          ),
          const Expanded(child: SizedBox()),
          SaveCollageButton(_widgetsToImageController),
          const SafeArea(
            child: SizedBox(
              height: 12,
            ),
          ),
        ],
      ),
    );
  }
}
