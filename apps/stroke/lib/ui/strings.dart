import 'package:flutter/widgets.dart';
import 'package:paper/paper.dart';

import '../domain/ink.dart';

/// Stroke's user-facing copy, English and Korean.
abstract class S {
  static const HandwrittenStrings<S> delegate = HandwrittenStrings<S>({
    'en': En.new,
    'ko': Ko.new,
  });

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? En();

  String get appName;
  String get newSketch;
  String get galleryEmptyTitle;
  String get galleryEmptyBody;
  String get untitled;
  String strokeCount(int strokes);
  String get rename;
  String get renameTitle;
  String get nameLabel;
  String get save;
  String get cancel;
  String get delete;
  String get deleteSketchTitle;
  String get deleteSketchBody;
  String get deleteSketchAction;

  String get done;
  String get undo;
  String get redo;
  String brushName(BrushKind kind);
  String get eraser;
  String get pan;
  String get size;
  String get colour;
  String get layers;
  String get addLayer;
  String get layerLimitReached;
  String get deleteLayer;
  String get clearLayer;
  String get layerOpacity;
  String get hideLayer;
  String get showLayer;
  String get moveUp;
  String get moveDown;
  String get renameLayer;
  String get fitToScreen;
  String zoomLabel(int percent);
  String get about;
  String get aboutBody;
}

class En implements S {
  @override
  String get appName => 'Stroke';
  @override
  String get newSketch => 'New sketch';
  @override
  String get galleryEmptyTitle => 'Nothing drawn yet';
  @override
  String get galleryEmptyBody =>
      'Sketches are stored on this device as plain JSON - readable, '
      'diffable, and yours.';
  @override
  String get untitled => 'Untitled';
  @override
  String strokeCount(int strokes) =>
      strokes == 1 ? '1 stroke' : '$strokes strokes';
  @override
  String get rename => 'Rename';
  @override
  String get renameTitle => 'Rename sketch';
  @override
  String get nameLabel => 'Name';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get deleteSketchTitle => 'Delete this sketch?';
  @override
  String get deleteSketchBody => 'It cannot be recovered.';
  @override
  String get deleteSketchAction => 'Delete';

  @override
  String get done => 'Done';
  @override
  String get undo => 'Undo';
  @override
  String get redo => 'Redo';
  @override
  String brushName(BrushKind kind) => switch (kind) {
    BrushKind.pen => 'Pen',
    BrushKind.marker => 'Marker',
    BrushKind.highlighter => 'Highlighter',
  };
  @override
  String get eraser => 'Eraser';
  @override
  String get pan => 'Move';
  @override
  String get size => 'Size';
  @override
  String get colour => 'Colour';
  @override
  String get layers => 'Layers';
  @override
  String get addLayer => 'Add layer';
  @override
  String get layerLimitReached => 'That is as many layers as a sketch gets.';
  @override
  String get deleteLayer => 'Delete layer';
  @override
  String get clearLayer => 'Clear layer';
  @override
  String get layerOpacity => 'Opacity';
  @override
  String get hideLayer => 'Hide layer';
  @override
  String get showLayer => 'Show layer';
  @override
  String get moveUp => 'Move up';
  @override
  String get moveDown => 'Move down';
  @override
  String get renameLayer => 'Rename layer';
  @override
  String get fitToScreen => 'Fit to screen';
  @override
  String zoomLabel(int percent) => '$percent%';
  @override
  String get about => 'About';
  @override
  String get aboutBody =>
      'Strokes are stored as points, not pixels, so a sketch stays sharp at '
      'any zoom and the file stays small. Nothing leaves the device.';
}

class Ko implements S {
  @override
  String get appName => '스트로크';
  @override
  String get newSketch => '새 스케치';
  @override
  String get galleryEmptyTitle => '아직 그린 그림이 없습니다';
  @override
  String get galleryEmptyBody =>
      '스케치는 이 기기에 평범한 JSON으로 저장됩니다. 읽을 수 있고, 비교할 수 있고, '
      '당신의 것입니다.';
  @override
  String get untitled => '제목 없음';
  @override
  String strokeCount(int strokes) => '획 $strokes개';
  @override
  String get rename => '이름 변경';
  @override
  String get renameTitle => '스케치 이름 변경';
  @override
  String get nameLabel => '이름';
  @override
  String get save => '저장';
  @override
  String get cancel => '취소';
  @override
  String get delete => '삭제';
  @override
  String get deleteSketchTitle => '이 스케치를 삭제할까요?';
  @override
  String get deleteSketchBody => '복구할 수 없습니다.';
  @override
  String get deleteSketchAction => '삭제';

  @override
  String get done => '완료';
  @override
  String get undo => '되돌리기';
  @override
  String get redo => '다시 실행';
  @override
  String brushName(BrushKind kind) => switch (kind) {
    BrushKind.pen => '펜',
    BrushKind.marker => '마커',
    BrushKind.highlighter => '형광펜',
  };
  @override
  String get eraser => '지우개';
  @override
  String get pan => '이동';
  @override
  String get size => '굵기';
  @override
  String get colour => '색';
  @override
  String get layers => '레이어';
  @override
  String get addLayer => '레이어 추가';
  @override
  String get layerLimitReached => '한 스케치의 레이어 수 한도입니다.';
  @override
  String get deleteLayer => '레이어 삭제';
  @override
  String get clearLayer => '레이어 비우기';
  @override
  String get layerOpacity => '불투명도';
  @override
  String get hideLayer => '레이어 숨기기';
  @override
  String get showLayer => '레이어 보이기';
  @override
  String get moveUp => '위로';
  @override
  String get moveDown => '아래로';
  @override
  String get renameLayer => '레이어 이름 변경';
  @override
  String get fitToScreen => '화면에 맞추기';
  @override
  String zoomLabel(int percent) => '$percent%';
  @override
  String get about => '정보';
  @override
  String get aboutBody =>
      '획은 픽셀이 아니라 점으로 저장됩니다. 그래서 어떤 배율에서도 선명하고 파일도 작습니다. '
      '아무것도 기기를 떠나지 않습니다.';
}
