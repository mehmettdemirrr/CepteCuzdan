import '../core/repositories/repository_contract.dart';
import 'fake_repositories.dart';

void main() {
  runRepositoryContract('Fake', () async {
    final f = FakeRepos();
    return RepoSet(
      txs: f.txs,
      categories: f.categories,
      budgets: f.budgets,
      chats: f.chats,
      close: () async {},
    );
  });
}
