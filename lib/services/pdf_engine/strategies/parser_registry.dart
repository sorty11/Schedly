import 'parser_strategy.dart';
import 'svkm_hybrid_strategy.dart';
import 'svkm_v1_strategy.dart';
import 'generic_row_strategy.dart';

class ParserRegistry {
  static final List<ParserStrategy> _strategies = [
    SvkmHybridStrategy(),
    SvkmV1Strategy(),
    GenericRowStrategy(),
  ];

  static List<ParserStrategy> get strategies => _strategies;
}
