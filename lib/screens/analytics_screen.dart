import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/activity.dart';
import '../state/finance_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _currentRoast;
  bool _isRoasting = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoast(Provider.of<FinanceState>(context, listen: false));
    });
  }

  Future<void> _fetchRoast(FinanceState state) async {
    setState(() {
      _isRoasting = true;
    });

    String newRoast = await _apiService.getRoast(state);
    
    if (mounted) {
      setState(() {
        _currentRoast = newRoast;
        _isRoasting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceState>(
      builder: (context, state, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildRoastCard(state),
               const SizedBox(height: 32),
               _buildSectionTitle("Stats Breakdown"),
               const SizedBox(height: 16),
               _buildStatsPieChart(state),
               const SizedBox(height: 32),
               _buildSectionTitle("Spend Breakdown"),
               const SizedBox(height: 16),
               _buildBreakdownChart(state),
               const SizedBox(height: 32),
               _buildSectionTitle("Overview"),
               const SizedBox(height: 16),
               _buildOverviewRow(state),
               const SizedBox(height: 16),
               _buildHighestSpendCard(state),
               const SizedBox(height: 32), // Padding for bottom nav
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.neonCyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRoastCard(FinanceState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)), // Greenish border like screenshot
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppTheme.success),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "FinBot 3000",
                    style: TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Roast Mode: ON",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          _isRoasting
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.success),
                  ),
                )
              : Text(
                  _currentRoast ?? "Something went wrong while roasting...",
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
        ],
      ),
    );
  }

  Widget _buildStatsPieChart(FinanceState state) {
    final totalSpends = state.recentActivity
        .where((a) => a.isExpense)
        .fold(0.0, (sum, a) => sum + a.amount);
    final goalDeductions = state.totalMonthlyGoalDeductions;
    final subs = state.subscriptions;
    final freeCash = state.safeBalance.clamp(0.0, double.infinity);
    final total = freeCash + subs + goalDeductions + totalSpends;

    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: const Center(child: Text("Set your Baseline to see breakdown.", style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final sections = [
      if (freeCash > 0)
        PieChartSectionData(color: AppTheme.neonCyan, value: freeCash, title: "", radius: 14),
      if (goalDeductions > 0)
        PieChartSectionData(color: AppTheme.success, value: goalDeductions, title: "", radius: 14),
      if (subs > 0)
        PieChartSectionData(color: AppTheme.neonPurple, value: subs, title: "", radius: 14),
      if (totalSpends > 0)
        PieChartSectionData(color: Colors.redAccent, value: totalSpends, title: "", radius: 14),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 75,
                  sections: sections,
                  borderData: FlBorderData(show: false),
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("FREE CASH", style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    Text("₹${freeCash.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendDot(AppTheme.neonCyan, "Free Cash ₹${freeCash.toStringAsFixed(0)}"),
              _buildLegendDot(AppTheme.success, "Goals ₹${goalDeductions.toStringAsFixed(0)}/mo"),
              _buildLegendDot(AppTheme.neonPurple, "Subs ₹${subs.toStringAsFixed(0)}"),
              _buildLegendDot(Colors.redAccent, "Spent ₹${totalSpends.toStringAsFixed(0)}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildBreakdownChart(FinanceState state) {
    // Group and calculate expenses
    double totalSpend = 0;
    Map<String, double> categorySums = {};
    for (var act in state.recentActivity) {
      if (act.isExpense) {
        totalSpend += act.amount;
        categorySums[act.category] = (categorySums[act.category] ?? 0) + act.amount;
      }
    }

    List<PieChartSectionData> sections = [];
    if (totalSpend > 0) {
      // Find largest category to color cyan, others purple variants
      String largestCategory = categorySums.keys.first;
      double maxVal = 0;
      categorySums.forEach((cat, val) {
        if (val > maxVal) { maxVal = val; largestCategory = cat; }
      });

      int colorIndex = 0;
      final otherColors = [AppTheme.neonPurple, Colors.purpleAccent, Colors.deepPurpleAccent];

      categorySums.forEach((category, value) {
        Color sliceColor = (category == largestCategory) 
            ? AppTheme.neonCyan 
            : otherColors[colorIndex % otherColors.length];
        if(category != largestCategory) colorIndex++;

        sections.add(PieChartSectionData(
          color: sliceColor,
          value: value,
          title: "", // No title in slice, or could add percentage
          radius: 12, // Thin donut ring
        ));
      });
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: totalSpend == 0 
      ? const Center(child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text("No spend data yet to breakdown.", style: TextStyle(color: AppTheme.textSecondary)),
        ))
      : SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 80,
                sections: sections,
                borderData: FlBorderData(show: false),
              )
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TOTAL", style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                Text("₹${totalSpend.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewRow(FinanceState state) {
    final monthlyGoals = state.totalMonthlyGoalDeductions;
    return Row(
      children: [
        Expanded(child: _buildOverviewMetric("Income", "₹${state.monthlyIncome.toStringAsFixed(0)}", "+8.2%", true)),
        const SizedBox(width: 16),
        Expanded(child: _buildOverviewMetric("Monthly Goals", "₹${monthlyGoals.toStringAsFixed(0)}", monthlyGoals > 0 ? "Active" : "None", monthlyGoals > 0)),
      ],
    );
  }

  Widget _buildOverviewMetric(String title, String value, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPositive ? Icons.trending_up : Icons.trending_down, size: 12, color: isPositive ? Colors.green : Colors.red),
                const SizedBox(width: 4),
                Text(change, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHighestSpendCard(FinanceState state) {
    // Calculate highest spend
    Activity? highestSpend;
    for (var act in state.recentActivity) {
      if (act.isExpense) {
        if (highestSpend == null || act.amount > highestSpend.amount) {
          highestSpend = act;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: highestSpend == null 
        ? const Center(child: Text("No recent spends recorded.", style: TextStyle(color: AppTheme.textSecondary)))
        : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Highest Spend", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(highestSpend.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            Text("-₹${highestSpend.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
    );
  }
}
