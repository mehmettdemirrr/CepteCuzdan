/// İşlem tipi. DB'de `.name` ile saklanır: `income` / `expense`.
enum TxType { income, expense }

/// Kaydın nereden geldiği. DB'de `.name` ile saklanır.
enum TxSource { manual, receipt, voice, chat }

/// Sohbet mesajının sahibi.
enum ChatRole { user, assistant }
