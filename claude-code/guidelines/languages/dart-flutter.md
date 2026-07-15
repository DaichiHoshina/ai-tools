# Dart / Flutter Guidelines

Dart 3.x + Flutter (hooks_riverpod + freezed + OpenAPI Client dio 系). Common guidelines: `~/.claude/guidelines/common/`.

## Core Principles

Java 系の翻訳的な書き方 (単一実装への抽象 IF/Impl 分割・Widget のメソッド分割・`Map<String, dynamic>` の生使用・生 `int` の ID・if-else ネスト) は、Dart 3 系の言語機能を活かせない。lint / null safety / pattern matching / sealed class の恩恵を取りに行く。

## 5 Rules

### 1. 抽象クラス禁止 (単一実装のみの場合)

Repository は `FooRepository` の 1 クラスのみ書く。`FooRepositoryImpl` は作らない。単一実装しかない抽象化はコスト過剰。

```dart
// NG: 単一実装への IF/Impl 分割
abstract class ProductRepository { Future<Product> find(ProductId id); }
class ProductRepositoryImpl implements ProductRepository { ... }

// OK: 1 クラスで書く
class ProductRepository {
  Future<Product> find(ProductId id) { ... }
}
```

`clean-architecture-ddd` skill が推奨する IF/Impl 分割とは方向が逆で、**Dart / Flutter 固有の判断**。複数実装 (mock 実装 / 環境別実装) が実際に存在する場合のみ IF を切る。

### 2. Widget 分割は private class

Widget の分割は `_Body` / `_Header` 等の `private class extends StatelessWidget` で行う。`Widget _buildBody()` のようなメソッド分割は避ける。

**Why**: メソッド分割は Widget tree の rebuild 単位が親と一体化してしまい、変更検知の粒度で不利。private class 分割なら rebuild が該当 sub-tree に閉じる。

```dart
// NG: メソッド分割
class MyPage extends StatelessWidget {
  Widget _buildBody() => Column(children: [...]);
  Widget _buildHeader() => AppBar(...);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: _buildHeader(), body: _buildBody());
}

// OK: private class 分割
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(appBar: _Header(), body: _Body());
}
class _Header extends StatelessWidget { ... }
class _Body extends StatelessWidget { ... }
```

### 3. ID は extension type

生 `int` を引き回さず `extension type` で型分離する。

```dart
extension type ProductId._(int value) implements int {}
extension type UserId._(int value) implements int {}

// NG: 生 int の混入で ProductId と UserId が交換可能になる
void addToCart(int productId, int userId) { ... }

// OK: 型で区別、渡し違いが compile error
void addToCart(ProductId productId, UserId userId) { ... }
```

`implements int` を付けると JSON serialize / DB layer で int として扱える一方、application 層では別型として扱われる。

### 4. `Map<String, dynamic>` を typedef 化

JSON 変換境界の型は `typedef` で名前を付けて閉じ込める。

```dart
typedef Json = Map<String, dynamic>;

// NG: 生 Map<String, dynamic> が API / repository / usecase を貫通
Product fromJson(Map<String, dynamic> json) { ... }

// OK: typedef で JSON 変換境界を明示
Product fromJson(Json json) { ... }
```

application 層のロジックに `Json` (=`Map<String, dynamic>`) が出てきたら「変換境界を越えて漏れている」signal になる。

### 5. Dart 3 switch 式で pattern matching

`switch` 式 + destructuring + sealed class の組合せで、null / 分岐漏れを compile-time に検知する。

```dart
sealed class OrderStatus {}
class Pending extends OrderStatus {}
class Shipped extends OrderStatus { Shipped(this.trackingNo); final String trackingNo; }
class Cancelled extends OrderStatus { Cancelled(this.reason); final String reason; }

String label(OrderStatus s) => switch (s) {
  Pending() => '準備中',
  Shipped(:final trackingNo) => '発送済 ($trackingNo)',
  Cancelled(:final reason) => 'キャンセル ($reason)',
};
```

sealed class + exhaustive check で、後から `Refunded` を追加したときに `label` が compile error になる。if-else / instanceof チェーンでは検知できない。

## Testing

- unit test は `test` package + `mocktail`
- Widget test は `flutter_test` + `pumpWidget` / `find.byType` / `find.text`
- freezed でモデルを作った場合、`copyWith` / `==` が自動生成されるので test assertion は等価比較で書く

## 参照実装 pattern

hooks_riverpod + freezed + OpenAPI Client (dio) 系プロジェクト。Riverpod の `Provider` / `Notifier` / `FutureProvider` の使い分けは Riverpod 3.x docs を参照する。

## 適用範囲外

- Dart で書かれた server (Shelf / Dart Frog 等) — Widget 関連 (§2) は対象外
- Go / TypeScript / Kotlin 系プロジェクト — これらでは `clean-architecture-ddd` skill 側の IF/Impl 推奨に従う

## 関連

- `guidelines/languages/README.md` (言語別規範一覧、無ければ本 file を追加)
- `clean-architecture-ddd` skill (§1 と方向が逆になる旨を本 file が明示)
