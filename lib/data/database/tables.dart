import 'package:drift/drift.dart';
import '../../core/models/transaction_type.dart';

@DataClassName('CategoryEntity')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionEntity')
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get category => text().references(Categories, #id)();
  TextColumn get merchant => text()();
  TextColumn get note => text()();
  TextColumn get receiptImagePath => text().nullable()();
  IntColumn get type => intEnum<TransactionType>()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionItemEntity')
class TransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().nullable()();
  RealColumn get weight => real().nullable()();
  RealColumn get total => real()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BudgetEntity')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get monthlyLimit => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingListEntity')
class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShoppingListItemEntity')
class ShoppingListItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().nullable()();
  RealColumn get total => real().withDefault(const Constant(0))();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
