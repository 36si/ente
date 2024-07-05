import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:logging/logging.dart";
import "package:media_extension/media_extension.dart";
import "package:media_extension/media_extension_action_types.dart";
import "package:photos/core/constants.dart";
import 'package:photos/models/file/file.dart';
import "package:photos/models/selected_files.dart";
import "package:photos/services/app_lifecycle_service.dart";
import "package:photos/states/pointer_provider.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/viewer/file/detail_page.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/ui/viewer/gallery/component/group/lazy_group_gallery.dart";
import "package:photos/ui/viewer/gallery/gallery.dart";
import "package:photos/ui/viewer/gallery/state/gallery_context_state.dart";
import "package:photos/utils/file_util.dart";
import "package:photos/utils/navigation_util.dart";

class GalleryFileWidget extends StatefulWidget {
  final EnteFile file;
  final SelectedFiles? selectedFiles;
  final bool limitSelectionToOne;
  final String tag;
  final int photoGridSize;
  final int? currentUserID;
  final List<EnteFile> filesInGroup;
  final GalleryLoader asyncLoader;
  const GalleryFileWidget({
    required this.file,
    required this.selectedFiles,
    required this.limitSelectionToOne,
    required this.tag,
    required this.photoGridSize,
    required this.currentUserID,
    required this.filesInGroup,
    required this.asyncLoader,
    super.key,
  });

  @override
  State<GalleryFileWidget> createState() => _GalleryFileWidgetState();
}

class _GalleryFileWidgetState extends State<GalleryFileWidget> {
  final _globalKey = GlobalKey();

  /// This does not always hold the correct value. This is used to unselect/select
  /// photos in swipe selection. It hold the right values during swipe selection
  /// so, it works fine for what it is used for.
  /// This can hold incorrect values when during onTap and certain cases of onLongPress.
  /// Too get a better idea, make this a ValueNotfier and update the UI when this changes.
  bool _pointerInsideBbox = false;
  bool _pointerInsideBboxPrevValue = false;
  late StreamSubscription<Offset> _pointerPositionStreamSubscription;
  late StreamSubscription<Offset> _pointerUpEventStreamSubscription;
  late StreamSubscription<Offset> _onTapEventStreamSubscription;
  late StreamSubscription<Offset> _onLongPressEventStreamSubscription;

  final _logger = Logger("GalleryFileWidget");

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.limitSelectionToOne) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            final RenderBox? renderBox =
                _globalKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox == null) {
              _logger.info("RenderBox is null. Returning.");
              return;
            }

            final groupGalleryGlobalKey =
                GroupGalleryGlobalKey.of(context).globalKey;

            final RenderBox? groupGalleryRenderBox =
                groupGalleryGlobalKey.currentContext?.findRenderObject()
                    as RenderBox?;
            if (groupGalleryRenderBox == null) {
              _logger.info("GroupGalleryRenderBox is null. Returning.");
              return;
            }

            final position = renderBox.localToGlobal(
              Offset.zero,
              ancestor: groupGalleryRenderBox,
            );

            final size = renderBox.size;

            final bbox = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );

            _onTapEventStreamSubscription = Pointer.of(context)
                .onTapStreamController
                .stream
                .listen((offset) {
              if (bbox.contains(offset)) {
                _pointerInsideBbox = true;
                widget.limitSelectionToOne
                    ? _onTapWithSelectionLimit(widget.file)
                    : _onTapNoSelectionLimit(context, widget.file);
              }
            });

            _onLongPressEventStreamSubscription = Pointer.of(context)
                .onLongPressStreamController
                .stream
                .listen((offset) {
              if (bbox.contains(offset)) {
                _pointerInsideBbox = true;
                widget.limitSelectionToOne
                    ? _onLongPressWithSelectionLimit(context, widget.file)
                    : _onLongPressNoSelectionLimit(context, widget.file);
              }
            });

            _pointerUpEventStreamSubscription = Pointer.of(context)
                .upOffsetStreamController
                .stream
                .listen((event) {
              if (bbox.contains(event)) {
                if (_pointerInsideBbox) _pointerInsideBbox = false;
              }
            });

            _pointerPositionStreamSubscription =
                Pointer.of(context).moveOffsetStreamController.stream.listen(
              (event) {
                if (widget.selectedFiles?.files.isEmpty ?? true) return;
                _pointerInsideBboxPrevValue = _pointerInsideBbox;

                if (bbox.contains(event)) {
                  _pointerInsideBbox = true;
                } else {
                  _pointerInsideBbox = false;
                }

                if (_pointerInsideBbox == true &&
                    _pointerInsideBboxPrevValue == false) {
                  widget.selectedFiles!.toggleSelection(widget.file);
                  LastSelectedFileByDragging.of(context).file.value =
                      widget.file;
                }
              },
              onError: (e) {
                _logger.warning("Error in pointer position subscription", e);
              },
              onDone: () {
                _logger.info("Pointer position subscription done");
              },
            );
          } catch (e) {
            _logger.warning("Error in pointer subscription", e);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _onTapEventStreamSubscription.cancel();
    _pointerPositionStreamSubscription.cancel();
    _pointerUpEventStreamSubscription.cancel();
    _onLongPressEventStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFileSelected =
        widget.selectedFiles?.isFileSelected(widget.file) ?? false;
    Color selectionColor = Colors.white;
    if (isFileSelected &&
        widget.file.isUploaded &&
        widget.file.ownerID != widget.currentUserID) {
      final avatarColors = getEnteColorScheme(context).avatarColors;
      selectionColor =
          avatarColors[(widget.file.ownerID!).remainder(avatarColors.length)];
    }
    final String heroTag = widget.tag + widget.file.tag;
    final Widget thumbnailWidget = ThumbnailWidget(
      widget.file,
      diskLoadDeferDuration: thumbnailDiskLoadDeferDuration,
      serverLoadDeferDuration: thumbnailServerLoadDeferDuration,
      shouldShowLivePhotoOverlay: true,
      key: Key(heroTag),
      thumbnailSize: widget.photoGridSize < photoGridSizeDefault
          ? thumbnailLargeSize
          : thumbnailSmallSize,
      shouldShowOwnerAvatar: !isFileSelected,
      shouldShowVideoDuration: true,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          key: _globalKey,
          borderRadius: BorderRadius.circular(1),
          child: Hero(
            tag: heroTag,
            flightShuttleBuilder: (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) =>
                thumbnailWidget,
            transitionOnUserGestures: true,
            child: isFileSelected
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(
                        0.4,
                      ),
                      BlendMode.darken,
                    ),
                    child: thumbnailWidget,
                  )
                : thumbnailWidget,
          ),
        ),
        isFileSelected
            ? Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: selectionColor, //same for both themes
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  void _toggleFileSelection(EnteFile file) {
    widget.selectedFiles!.toggleSelection(file);
  }

  void _onTapWithSelectionLimit(EnteFile file) {
    if (widget.selectedFiles!.files.isNotEmpty &&
        widget.selectedFiles!.files.first != file) {
      widget.selectedFiles!.clearAll();
    }
    _toggleFileSelection(file);
  }

  void _onTapNoSelectionLimit(BuildContext context, EnteFile file) async {
    final bool shouldToggleSelection =
        (widget.selectedFiles?.files.isNotEmpty ?? false) ||
            GalleryContextState.of(context)!.inSelectionMode;
    if (shouldToggleSelection) {
      _toggleFileSelection(file);
    } else {
      if (AppLifecycleService.instance.mediaExtensionAction.action ==
          IntentAction.pick) {
        final ioFile = await getFile(file);
        await MediaExtension().setResult("file://${ioFile!.path}");
      } else {
        _routeToDetailPage(file, context);
      }
    }
  }

  void _onLongPressNoSelectionLimit(BuildContext context, EnteFile file) {
    if (widget.selectedFiles!.files.isNotEmpty) {
      _routeToDetailPage(file, context);
    } else if (AppLifecycleService.instance.mediaExtensionAction.action ==
        IntentAction.main) {
      HapticFeedback.lightImpact();
      _toggleFileSelection(file);
    }
  }

  Future<void> _onLongPressWithSelectionLimit(
    BuildContext context,
    EnteFile file,
  ) async {
    if (AppLifecycleService.instance.mediaExtensionAction.action ==
        IntentAction.pick) {
      final ioFile = await getFile(file);
      await MediaExtension().setResult("file://${ioFile!.path}");
    } else {
      _routeToDetailPage(file, context);
    }
  }

  void _routeToDetailPage(EnteFile file, BuildContext context) {
    final page = DetailPage(
      DetailPageConfiguration(
        List.unmodifiable(widget.filesInGroup),
        widget.asyncLoader,
        widget.filesInGroup.indexOf(file),
        widget.tag,
        sortOrderAsc: GalleryContextState.of(context)!.sortOrderAsc,
      ),
    );
    routeToPage(context, page, forceCustomPageRoute: true);
  }
}
