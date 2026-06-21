import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/filter_provider.dart';
import '../utils/log_scale_mapper.dart';

final _compact = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

class FinancialThresholdFilter extends StatefulWidget {
  const FinancialThresholdFilter({super.key});

  @override
  State<FinancialThresholdFilter> createState() =>
      _FinancialThresholdFilterState();
}

class _FinancialThresholdFilterState extends State<FinancialThresholdFilter> {
  late final TextEditingController _valorMinCtrl;
  late final TextEditingController _valorMaxCtrl;
  late final TextEditingController _remMinCtrl;
  late final TextEditingController _remMaxCtrl;

  @override
  void initState() {
    super.initState();
    final state = context.read<FilterProvider>().state;
    _valorMinCtrl = TextEditingController(
        text: state.valorContratoMin.toStringAsFixed(0));
    _valorMaxCtrl = TextEditingController(
        text: state.valorContratoMax.toStringAsFixed(0));
    _remMinCtrl = TextEditingController(
        text: state.remuneracaoMin.toStringAsFixed(0));
    _remMaxCtrl = TextEditingController(
        text: state.remuneracaoMax.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _valorMinCtrl.dispose();
    _valorMaxCtrl.dispose();
    _remMinCtrl.dispose();
    _remMaxCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFromState() {
    final state = context.read<FilterProvider>().state;
    final vMin = state.valorContratoMin.toStringAsFixed(0);
    final vMax = state.valorContratoMax.toStringAsFixed(0);
    final rMin = state.remuneracaoMin.toStringAsFixed(0);
    final rMax = state.remuneracaoMax.toStringAsFixed(0);
    if (_valorMinCtrl.text != vMin) _valorMinCtrl.text = vMin;
    if (_valorMaxCtrl.text != vMax) _valorMaxCtrl.text = vMax;
    if (_remMinCtrl.text != rMin) _remMinCtrl.text = rMin;
    if (_remMaxCtrl.text != rMax) _remMaxCtrl.text = rMax;
  }

  void _applyValorContrato(FilterProvider filter, double maxValor) {
    final min = double.tryParse(_valorMinCtrl.text) ?? 0;
    final max = double.tryParse(_valorMaxCtrl.text) ?? maxValor;
    final clampedMin = min.clamp(0, maxValor).toDouble();
    final clampedMax = max.clamp(0, maxValor).toDouble();
    filter.updateFinancial(
      valorMin: clampedMin,
      valorMax: clampedMax >= clampedMin ? clampedMax : clampedMin,
    );
  }

  void _applyRemuneracao(FilterProvider filter, double maxRem) {
    final min = double.tryParse(_remMinCtrl.text) ?? 0;
    final max = double.tryParse(_remMaxCtrl.text) ?? maxRem;
    final clampedMin = min.clamp(0, maxRem).toDouble();
    final clampedMax = max.clamp(0, maxRem).toDouble();
    filter.updateFinancial(
      remMin: clampedMin,
      remMax: clampedMax >= clampedMin ? clampedMax : clampedMin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterProvider>();
    final data = context.read<DataProvider>();
    final state = filter.state;
    final maxValor = data.maxValorContrato;
    final maxRem = data.maxRemuneracao;

    // Sync controllers when state changes externally (e.g. reset)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncControllersFromState();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valor do contrato: ${_compact.format(state.valorContratoMin)} – ${_compact.format(state.valorContratoMax)}',
        ),
        Builder(builder: (context) {
          final mapper = LogScaleMapper(minValue: 0, maxValue: maxValor);
          final isFlat = maxValor == 0;
          return RangeSlider(
            values: RangeValues(
              mapper.toPosition(state.valorContratoMin),
              mapper.toPosition(state.valorContratoMax),
            ),
            min: 0.0,
            max: 1.0,
            labels: RangeLabels(
              _compact.format(state.valorContratoMin),
              _compact.format(state.valorContratoMax),
            ),
            onChanged: isFlat
                ? null
                : (v) {
                    filter.updateFinancial(
                      valorMin: mapper.toValue(v.start),
                      valorMax: mapper.toValue(v.end),
                    );
                  },
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _valorMinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mín',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onEditingComplete: () => _applyValorContrato(filter, maxValor),
                onFieldSubmitted: (_) => _applyValorContrato(filter, maxValor),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _valorMaxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Máx',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onEditingComplete: () => _applyValorContrato(filter, maxValor),
                onFieldSubmitted: (_) => _applyValorContrato(filter, maxValor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Remuneração: ${_compact.format(state.remuneracaoMin)} – ${_compact.format(state.remuneracaoMax)}',
        ),
        Builder(builder: (context) {
          final mapper = LogScaleMapper(minValue: 0, maxValue: maxRem);
          final isFlat = maxRem == 0;
          return RangeSlider(
            values: RangeValues(
              mapper.toPosition(state.remuneracaoMin),
              mapper.toPosition(state.remuneracaoMax),
            ),
            min: 0.0,
            max: 1.0,
            labels: RangeLabels(
              _compact.format(state.remuneracaoMin),
              _compact.format(state.remuneracaoMax),
            ),
            onChanged: isFlat
                ? null
                : (v) {
                    filter.updateFinancial(
                      remMin: mapper.toValue(v.start),
                      remMax: mapper.toValue(v.end),
                    );
                  },
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _remMinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mín',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onEditingComplete: () => _applyRemuneracao(filter, maxRem),
                onFieldSubmitted: (_) => _applyRemuneracao(filter, maxRem),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _remMaxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Máx',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onEditingComplete: () => _applyRemuneracao(filter, maxRem),
                onFieldSubmitted: (_) => _applyRemuneracao(filter, maxRem),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
