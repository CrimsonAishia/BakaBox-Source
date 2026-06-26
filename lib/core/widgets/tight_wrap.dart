import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 一个紧凑排列的 Wrap，当一行放不下当前的子组件时，会往后寻找能够放得下的子组件，
/// 将其“提”上来填补空白，使得排版更加紧凑（贪心排版）。
class TightWrap extends MultiChildRenderObjectWidget {
  final double spacing;
  final double runSpacing;

  const TightWrap({
    super.key,
    this.spacing = 0.0,
    this.runSpacing = 0.0,
    super.children,
  });

  @override
  RenderTightWrap createRenderObject(BuildContext context) {
    return RenderTightWrap(
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTightWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class TightWrapParentData extends ContainerBoxParentData<RenderBox> {}

class RenderTightWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TightWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TightWrapParentData> {
  double _spacing;
  double _runSpacing;

  RenderTightWrap({
    List<RenderBox>? children,
    double spacing = 0.0,
    double runSpacing = 0.0,
  })  : _spacing = spacing,
        _runSpacing = runSpacing {
    addAll(children);
  }

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TightWrapParentData) {
      child.parentData = TightWrapParentData();
    }
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final BoxConstraints childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);

    // 1. 测量所有子组件并收集到一个未放置列表中
    final List<RenderBox> unplacedChildren = [];
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      unplacedChildren.add(child);
      final TightWrapParentData childParentData = child.parentData! as TightWrapParentData;
      child = childParentData.nextSibling;
    }

    // 2. 贪心算法摆放
    double currentX = 0;
    double currentY = 0;
    double maxRowHeight = 0;
    double maxTotalWidth = 0;

    while (unplacedChildren.isNotEmpty) {
      bool placedAnyInRow = false;

      // 遍历未放置的子组件，看谁能塞进当前行的剩余空间
      for (int i = 0; i < unplacedChildren.length; i++) {
        final candidate = unplacedChildren[i];
        final double childWidth = candidate.size.width;
        
        // 如果当前行是空的，必须放一个（哪怕超出 maxWidth）
        // 如果当前行不是空的，检查剩余空间是否足够 (考虑 spacing)
        final bool isRowEmpty = !placedAnyInRow;
        final double requiredWidth = isRowEmpty ? childWidth : (childWidth + _spacing);

        if (isRowEmpty || currentX + requiredWidth <= constraints.maxWidth) {
          // 放在当前行
          final TightWrapParentData candidateParentData = candidate.parentData! as TightWrapParentData;
          candidateParentData.offset = Offset(currentX + (isRowEmpty ? 0 : _spacing), currentY);
          
          currentX += requiredWidth;
          if (candidate.size.height > maxRowHeight) {
            maxRowHeight = candidate.size.height;
          }
          if (currentX > maxTotalWidth) {
            maxTotalWidth = currentX;
          }
          
          placedAnyInRow = true;
          unplacedChildren.removeAt(i);
          i--; // 因为移除了元素，索引回退
        }
      }

      // 这一行已经塞不下任何剩下的子组件了，换行
      if (unplacedChildren.isNotEmpty) {
        currentX = 0;
        currentY += maxRowHeight + _runSpacing;
        maxRowHeight = 0; // 重置下一行的最大高度
      }
    }

    // 计算总尺寸
    size = constraints.constrain(Size(maxTotalWidth, currentY + maxRowHeight));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
