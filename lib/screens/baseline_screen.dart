import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/finance_state.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../utils/route_transitions.dart';

class BaselineScreen extends StatefulWidget {
  const BaselineScreen({super.key});

  @override
  State<BaselineScreen> createState() => _BaselineScreenState();
}

class _BaselineScreenState extends State<BaselineScreen> {
  late TextEditingController _incomeController;
  late TextEditingController _balanceController;
  late TextEditingController _goalNameController;
  late TextEditingController _goalTargetController;
  late TextEditingController _goalMonthsController;
  late TextEditingController _subsController;
  late TextEditingController _commuteController;

  late FocusNode _incomeFocus;
  late FocusNode _balanceFocus;
  late FocusNode _goalNameFocus;
  late FocusNode _goalTargetFocus;
  late FocusNode _goalMonthsFocus;
  late FocusNode _subsFocus;
  late FocusNode _commuteFocus;

  List<Goal> _tempGoals = [];

  @override
  void initState() {
    super.initState();
    final state = Provider.of<FinanceState>(context, listen: false);
    _incomeController = TextEditingController(text: state.monthlyIncome.toStringAsFixed(0));
    _balanceController = TextEditingController(text: state.safeBalance.toStringAsFixed(0));
    _goalNameController = TextEditingController();
    _goalTargetController = TextEditingController();
    _goalMonthsController = TextEditingController();
    _subsController = TextEditingController(text: state.subscriptions.toStringAsFixed(0));
    _commuteController = TextEditingController(text: state.dailyCommute.toStringAsFixed(0));

    _incomeFocus = FocusNode();
    _balanceFocus = FocusNode();
    _goalNameFocus = FocusNode();
    _goalTargetFocus = FocusNode();
    _goalMonthsFocus = FocusNode();
    _subsFocus = FocusNode();
    _commuteFocus = FocusNode();

    _tempGoals = List.from(state.goals);

    // Listen to controllers to rebuild UI for real-time feasibility checking
    _incomeController.addListener(_onInputChanged);
    _subsController.addListener(_onInputChanged);
    _commuteController.addListener(_onInputChanged);
    _goalTargetController.addListener(_onInputChanged);
    _goalMonthsController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    setState(() {}); // Re-trigger build to update feasibility button state
  }

  @override
  void dispose() {
    _incomeController.removeListener(_onInputChanged);
    _subsController.removeListener(_onInputChanged);
    _commuteController.removeListener(_onInputChanged);
    _goalTargetController.removeListener(_onInputChanged);
    _goalMonthsController.removeListener(_onInputChanged);
    
    _incomeController.dispose();
    _balanceController.dispose();
    _goalNameController.dispose();
    _goalTargetController.dispose();
    _goalMonthsController.dispose();

    _incomeFocus.dispose();
    _balanceFocus.dispose();
    _goalNameFocus.dispose();
    _goalTargetFocus.dispose();
    _goalMonthsFocus.dispose();
    _subsFocus.dispose();
    _commuteFocus.dispose();
    _subsController.dispose();
    _commuteController.dispose();
    super.dispose();
  }

  double get _freeToSpend {
    double income = double.tryParse(_incomeController.text) ?? 0.0;
    double subs = double.tryParse(_subsController.text) ?? 0.0;
    double commute = double.tryParse(_commuteController.text) ?? 0.0;
    
    double existingGoalsMonthly = 0;
    for (var goal in _tempGoals) {
      int months = goal.monthsToAchieve ?? 1;
      if (months < 1) months = 1;
      existingGoalsMonthly += (goal.targetAmount / months);
    }
    return income - subs - (commute * 30) - existingGoalsMonthly;
  }

  int get _calculatedMonths {
    int parsed = int.tryParse(_goalMonthsController.text) ?? 0;
    if (parsed > 0) return parsed;
    
    double target = double.tryParse(_goalTargetController.text) ?? 0.0;
    if (target <= 0.0) return 0;
    
    double free = _freeToSpend;
    if (free <= 0) return 0;
    
    return (target / free).ceil();
  }

  double get _requiredMonthly {
    double target = double.tryParse(_goalTargetController.text) ?? 0.0;
    int months = _calculatedMonths;
    if (months < 1) return 0;
    return target / months;
  }

  bool get _isGoalFeasible {
    double req = _requiredMonthly;
    return req > 0 && req <= _freeToSpend && _goalNameController.text.isNotEmpty;
  }

  void _addLocalGoal() {
    if (!_isGoalFeasible) return;
    
    double target = double.tryParse(_goalTargetController.text) ?? 0.0;
    int months = _calculatedMonths;
    if (months < 1) months = 1;

    setState(() {
      _tempGoals.add(Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _goalNameController.text,
        targetAmount: target,
        monthsToAchieve: months,
        savedAmount: 0,
      ));
      
      _goalNameController.clear();
      _goalTargetController.clear();
      _goalMonthsController.clear();
    });
  }

  void _saveBaseline() {
    final state = Provider.of<FinanceState>(context, listen: false);
    double income = double.tryParse(_incomeController.text) ?? state.monthlyIncome;
    double subs = double.tryParse(_subsController.text) ?? state.subscriptions;
    double commute = double.tryParse(_commuteController.text) ?? state.dailyCommute;

    // Auto-push any pending goal input the user typed but didn't tap "+ Add Goal"
    final pendingName = _goalNameController.text.trim();
    final pendingTarget = double.tryParse(_goalTargetController.text) ?? 0.0;
    if (pendingName.isNotEmpty && pendingTarget > 0) {
      int months = _calculatedMonths;
      if (months < 1) months = 1;
      final headStart = pendingTarget / months;
      _tempGoals.add(Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: pendingName,
        targetAmount: pendingTarget,
        monthsToAchieve: months,
        savedAmount: headStart, // 1-month head-start
      ));
    }

    state.updateBaseline(income, subs, commute);
    state.replaceGoals(_tempGoals);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DashboardScreen()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Edit Baseline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context) 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIncomeCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInfoCardInput(
                  "SUBSCRIPTIONS", _subsController, _subsFocus, AppTheme.neonPurple,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _commuteFocus.requestFocus(),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildInfoCardInput(
                  "DAILY\nCOMMUTE", _commuteController, _commuteFocus, Colors.orangeAccent,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _balanceFocus.requestFocus(),
                )),
              ],
            ),
            const SizedBox(height: 32),
            _buildInputField(
              "CURRENT SAFE BALANCE", _balanceController, _balanceFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _goalNameFocus.requestFocus(),
            ),
            const SizedBox(height: 40),

            // RENDER GOALS ABOVE THE FORM
            const Text("Savings Goals", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            if (_tempGoals.isEmpty) 
               const Padding(
                 padding: EdgeInsets.only(bottom: 24.0),
                 child: Text("No active goals added yet.", style: TextStyle(color: AppTheme.textSecondary)),
               )
            else
               Column(
                children: _tempGoals.map((goal) => _buildGoalCard(goal)).toList(),
               ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("What are we saving for?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Icon(Icons.check_circle_outline, color: AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSimpleInput(
                  "Goal Name (e.g., PS5)", _goalNameController, _goalNameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _goalTargetFocus.requestFocus(),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleInput(
                  "Target (₹)", _goalTargetController, _goalTargetFocus, isNumeric: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _goalMonthsFocus.requestFocus(),
                )),
              ],
            ),
            const SizedBox(height: 12),
            _buildSimpleInput(
              "Months to Achieve (Optional)", _goalMonthsController, _goalMonthsFocus, isNumeric: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
                if (_isGoalFeasible) _addLocalGoal();
              },
            ),
            const SizedBox(height: 12),

            // FEASIBILITY CHECKER UI
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _isGoalFeasible ? AppTheme.success.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isGoalFeasible ? AppTheme.success.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   Icon(_isGoalFeasible ? Icons.check_circle : Icons.warning, color: _isGoalFeasible ? AppTheme.success : Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isGoalFeasible 
                        ? (_goalMonthsController.text.isEmpty && _requiredMonthly > 0 
                            ? "Feasible! Auto-calculated $_calculatedMonths months needed (₹${_requiredMonthly.toStringAsFixed(0)}/mo) out of your free ₹${_freeToSpend.toStringAsFixed(0)}/mo."
                            : "Feasible! This requires ₹${_requiredMonthly.toStringAsFixed(0)}/mo out of your free ₹${_freeToSpend.toStringAsFixed(0)}/mo.")
                        : _requiredMonthly > 0 
                            ? "Too expensive! This needs ₹${(_requiredMonthly == double.infinity ? "-" : _requiredMonthly.toStringAsFixed(0))}/mo, but you only have ₹${_freeToSpend.toStringAsFixed(0)}/mo free."
                            : "Enter a goal name and target to check feasibility.",
                      style: TextStyle(color: _isGoalFeasible ? AppTheme.success : Colors.redAccent, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGoalFeasible ? _addLocalGoal : null,
                icon: Icon(Icons.add, color: _isGoalFeasible ? AppTheme.success : Colors.white30, size: 16),
                label: Text("Add Saving/Goal", style: TextStyle(color: _isGoalFeasible ? AppTheme.success : Colors.white30)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _isGoalFeasible ? AppTheme.success.withOpacity(0.5) : Colors.white10),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 48), // Padding before final save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBaseline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Save Baseline & Start", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("BASE INCOME", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text("₹", style: TextStyle(color: AppTheme.success, fontSize: 32, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: TextField(
                      controller: _incomeController,
                      focusNode: _incomeFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _subsFocus.requestFocus(),
                      style: const TextStyle(color: AppTheme.success, fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _incomeFocus.requestFocus(),
              child: const Icon(Icons.edit, color: AppTheme.neonCyan, size: 16),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCardInput(String title, TextEditingController controller, FocusNode focusNode, Color accentColor, {TextInputAction? textInputAction, void Function(String)? onSubmitted}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text("-₹", style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: textInputAction,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => focusNode.requestFocus(),
              child: Icon(Icons.edit, color: accentColor, size: 16),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInputField(String title, TextEditingController controller, FocusNode focusNode, {TextInputAction? textInputAction, void Function(String)? onSubmitted}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Text("₹ ", style: TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold)),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: GestureDetector(
                      onTap: () => focusNode.requestFocus(),
                      child: const Icon(Icons.edit, color: AppTheme.neonCyan, size: 16),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleInput(String hint, TextEditingController controller, FocusNode focusNode, {bool isNumeric = false, TextInputAction? textInputAction, void Function(String)? onSubmitted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          border: InputBorder.none,
          suffixIcon: GestureDetector(
            onTap: () => focusNode.requestFocus(),
            child: const Icon(Icons.edit, color: Colors.white54, size: 16),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "₹${goal.savedAmount.toInt()} saved / ₹${goal.targetAmount.toInt()} (${goal.monthsToAchieve ?? '?'}m)",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _goalNameController.text = goal.name;
                    _goalTargetController.text = goal.targetAmount.toStringAsFixed(0);
                    _goalMonthsController.text = goal.monthsToAchieve?.toString() ?? '';
                    _tempGoals.removeWhere((g) => g.id == goal.id);
                  });
                  _goalNameFocus.requestFocus();
                },
                child: const Icon(Icons.edit, color: Colors.white54, size: 16),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text("Delete Goal?", style: TextStyle(color: Colors.white)),
                      content: Text(
                        "Remove \"${goal.name}\"? Its monthly deduction will be refunded to your free cash pool.",
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Delete", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    setState(() {
                      _tempGoals.removeWhere((g) => g.id == goal.id);
                    });
                  }
                },
                child: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
