class ApiEndpoints {
  static const health = '/api/health';

  // Auth (no token required)
  static const authLogin = '/api/auth/login';
  static const authRegister = '/api/auth/register';

  // Transactions
  static const transactions = '/api/transactions';
  static const transactionsExists = '/api/transactions/exists';
  static String transactionById(String id) => '/api/transactions/$id';
  static const transactionsRecent = '/api/transactions/recent';
  static const transactionsMonthlySummary = '/api/transactions/summary/monthly';
  static const transactionsNetWorth = '/api/transactions/summary/net-worth';
  static const transactionsCategoryBreakdown =
      '/api/transactions/breakdown/category';
  static const transactionsDailyBreakdown =
      '/api/transactions/breakdown/daily';
  static const transactionsMonthlySavings = '/api/transactions/savings/monthly';

  // Goals
  static const goals = '/api/goals';
  static const goalsActive = '/api/goals/active';
  static String goalById(String id) => '/api/goals/$id';
  static String goalContribute(String id) => '/api/goals/$id/contribute';

  // Budgets
  static const budgetsCurrent = '/api/budgets/current';
  static const budgets = '/api/budgets';
  static String budgetById(String id) => '/api/budgets/$id';

  // Investments
  static const investments = '/api/investments';
  static const investmentsTotalValue = '/api/investments/total-value';
  static const investmentsAllocation = '/api/investments/allocation';
  static String investmentById(String id) => '/api/investments/$id';
  static const investmentSnapshots = '/api/investments/snapshots';

  // Profile
  static const profile = '/api/profile';

  // Chat
  static const chat = '/api/chat';
}
