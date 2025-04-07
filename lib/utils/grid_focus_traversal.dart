import 'package:flutter/widgets.dart';

@immutable
class GridFocusTraversalPolicy extends FocusTraversalPolicy {
  final int columns;

  const GridFocusTraversalPolicy({this.columns = 5});

  @override
  FocusNode? findFirstFocus(
    FocusNode currentNode, {
    bool ignoreCurrentFocus = false,
  }) {
    return currentNode.enclosingScope?.traversalDescendants.firstOrNull;
  }

  @override
  FocusNode findFirstFocusInDirection(
    FocusNode currentNode,
    TraversalDirection direction,
  ) {
    final nextNode = _findNodeInDirection(currentNode, direction);
    return nextNode ?? currentNode;
  }

  @override
  FocusNode findLastFocus(
    FocusNode currentNode, {
    bool ignoreCurrentFocus = false,
  }) {
    final last = currentNode.enclosingScope?.traversalDescendants.lastOrNull;
    return last ?? currentNode;
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final nextNode = _findNodeInDirection(currentNode, direction);
    if (nextNode != null) {
      nextNode.requestFocus();
      return true;
    }
    return false;
  }

  FocusNode? _findNodeInDirection(
    FocusNode currentNode,
    TraversalDirection direction,
  ) {
    final descendants =
        currentNode.enclosingScope?.traversalDescendants.toList() ?? [];
    if (descendants.isEmpty) return null;

    final currentIndex = descendants.indexOf(currentNode);
    if (currentIndex == -1) return null;

    int nextIndex;
    switch (direction) {
      case TraversalDirection.up:
        nextIndex = currentIndex - columns;
        if (nextIndex < 0) return null;
        break;
      case TraversalDirection.down:
        nextIndex = currentIndex + columns;
        if (nextIndex >= descendants.length) return null;
        break;
      case TraversalDirection.left:
        if (currentIndex % columns == 0) return null;
        nextIndex = currentIndex - 1;
        break;
      case TraversalDirection.right:
        if ((currentIndex + 1) % columns == 0) return null;
        nextIndex = currentIndex + 1;
        break;
    }

    if (nextIndex >= 0 && nextIndex < descendants.length) {
      return descendants[nextIndex];
    }

    return null;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    return descendants;
  }
}
