/// Riverpod retry policy for the whole app: never retry automatically.
///
/// Riverpod 3 retries failed providers by default. Here that only hides
/// errors behind a spinner: Firestore streams already reconnect by
/// themselves when the network returns, and the remaining errors (permission
/// denied, missing index) do not fix themselves. Screens show an [ErrorView]
/// with a "Try again" button instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
