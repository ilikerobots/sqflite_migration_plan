library sqflite_migration_plan;

import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

/// A discrete (and possibly reversible) database change.
///
/// A Migration consists minimally of a [forward] [Operation] which serves to
/// perform a discrete step of an upgrade process.  A [reverse] Operation
/// that undoes this change during downgrades may also be specified.
class Migration {
  final Operation forward;
  final Operation reverse;

  /// Construct a migration from its constituent [forward] [Operation] and
  /// optionally [reverse].
  ///
  /// For use in scenarios where the database may be downgraded, [reverse] is
  /// the operation that "undoes" the forward operation. It not always
  /// necessary or possible for the forward and reverse operations to be
  /// true inverses. Instead, the reverse should restore the database back to
  /// a suitable state such that A) prior versions of code that do not expect
  /// this operation may operate and B) the upgrade can be reapplied as
  /// expected.
  ///
  /// The default [reverse] operation is [noop].
  Migration(this.forward, {reverse})
      : this.reverse = reverse ?? Operation<void>(noop);
}
