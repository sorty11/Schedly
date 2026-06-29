import 'package:flutter/widgets.dart';

class TargetRegistry extends ChangeNotifier {
  static final TargetRegistry instance = TargetRegistry._();
  TargetRegistry._();

  final Map<String, GlobalKey> _targets = {};
  
  void register(String id, GlobalKey key) {
    _targets[id] = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  void unregister(String id) {
    _targets.remove(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  GlobalKey? getKey(String id) {
    return _targets[id];
  }
  
  Rect? getBounds(String id) {
    final key = _targets[id];
    if (key == null || key.currentContext == null) return null;
    
    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    if (!renderBox.hasSize) return null;
    
    final position = renderBox.localToGlobal(Offset.zero);
    return position & renderBox.size;
  }
}

class TutorialTarget extends StatefulWidget {
  final String id;
  final Widget child;
  
  const TutorialTarget({
    super.key,
    required this.id,
    required this.child,
  });

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  final GlobalKey _key = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    TargetRegistry.instance.register(widget.id, _key);
  }
  
  @override
  void dispose() {
    TargetRegistry.instance.unregister(widget.id);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
