import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isZh => locale.languageCode == 'zh';
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;
  String t(String key, [Map<String, Object> values = const {}]) {
    final pair = _strings[key];
    var value = pair == null
        ? key
        : isZh
        ? pair.$1
        : pair.$2;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  String error(String code) => _strings.containsKey('error.$code')
      ? t('error.$code')
      : t('error.generic');

  static const delegate = _StringsDelegate();
  static const supportedLocales = [Locale('zh'), Locale('en')];
  static Locale resolveLocales(List<Locale> locales) {
    for (final locale in locales) {
      if (locale.languageCode == 'zh') return const Locale('zh');
      if (locale.languageCode == 'en') return const Locale('en');
    }
    return const Locale('en');
  }

  static const _strings = <String, (String, String)>{
    'profileMenu': ('账户与设置', 'Account and settings'),
    'registeredPlayer': ('已登录账户', 'Signed in'),
    'guestLocal': ('棋谱保存在此设备', 'Games saved on this device'),
    'guestName': ('棋友 {suffix}', 'Player {suffix}'),
    'homeTitle': ('来一局。', 'Your move.'),
    'homeCaption': ('一方棋盘，两位好对手。', 'One board. Two good opponents.'),
    'resumeTitle': ('接着下。', 'Pick up your game.'),
    'resumeCaption': ('棋局还在，下一手等你。', 'Your board is right where you left it.'),
    'playTogether': ('同屏开局', 'Start pass & play'),
    'playOnline': ('好友对弈', 'Play online'),
    'localShort': ('两人 · 一块屏幕', 'Two players · One screen'),
    'onlineShort': ('分享房间码，随时相聚', 'Meet over a room code'),
    'returnRoom': ('返回房间', 'Return to room'),
    'alsoLocal': ('继续同屏棋局', 'Continue pass & play'),
    'gameOptions': ('对局选项', 'Game options'),
    'gameSettings': ('对局设置', 'Game settings'),
    'clearSelection': ('取消预选', 'Cancel selection'),
    'placing': ('正在落子…', 'Placing stone…'),
    'chooseMove': ('选择落点', 'Choose a move'),
    'roomDetails': ('房间信息', 'Room details'),
    'matchDetails': ('棋局信息', 'Game details'),
    'inviteTitle': ('邀请一位好对手', 'Save a seat for a friend'),
    'roomSetup': ('先认识一下', 'Make yourself known'),
    'createRoomBody': (
      '生成房间码，邀请朋友加入。',
      'Get a room code to share with a friend.',
    ),
    'joinRoomBody': (
      '输入朋友发来的六位房间码。',
      'Enter the six-character code from your friend.',
    ),
    'connectionUnavailable': ('暂时无法连接联机服务', 'Online service is unavailable'),
    'connectionChecking': ('正在检查连接…', 'Checking connection…'),
    'readyCaption': (
      '双方准备后，黑棋先行。',
      'When both players are ready, black goes first.',
    ),
    'libraryTitle': ('每一局，都有故事。', 'Every game has a story.'),
    'libraryEmpty': ('还没有棋谱', 'No games yet'),
    'filterEmpty': ('这一分类还没有棋谱', 'No games in this category'),
    'filterEmptyBody': (
      '试试其他分类，或开始一局新的对弈。',
      'Try another filter, or start a new game.',
    ),
    'players': ('{black} · {white}', '{black} · {white}'),
    'appearanceSection': ('外观', 'Appearance'),
    'accessibilitySection': ('语言与无障碍', 'Language & accessibility'),
    'playingSection': ('对局', 'Playing'),
    'colorFromSystem': ('当前使用系统配色', 'Using system colors'),
    'colorPreview': ('你的配色', 'Your palette'),
    'preferencesCaption': ('选一种颜色，找到自己的节奏。', 'Your color. Your pace.'),
    'accountCaption': ('把每一局，带到下一台设备。', 'Take your games to your next device.'),
    'accountDetails': ('账户资料', 'Account details'),
    'editEmail': ('修改邮箱地址', 'Change email address'),
    'emailStep': ('第 1 步 · 邮箱', 'Step 1 · Email'),
    'verifyStep': ('第 2 步 · 验证并完成', 'Step 2 · Verify and finish'),
    'emailError': ('请输入有效的邮箱地址', 'Enter a valid email address'),
    'pickAccount': ('选择账号', 'Choose account'),
    'accountOne': ('账号 1', 'Account 1'),
    'accountTwo': ('账号 2', 'Account 2'),
    'privatePasswordHint': (
      '管理员提供的 8 位数字密码',
      'The 8-digit password from your administrator',
    ),
    'passwordError': ('请输入密码', 'Enter your password'),
    'codeError': ('请输入邮件中的验证码', 'Enter the code from your email'),
    'error.local_game_updated': (
      '另一个窗口更新了棋局，已恢复最新进度，请重新落子。',
      'Another window updated this game. The latest position is restored; choose your move again.',
    ),
    'appName': ('五子棋', 'Gomoku'),
    'play': ('对弈', 'Play'),
    'history': ('棋谱', 'Library'),
    'settings': ('设置', 'Settings'),
    'account': ('账户', 'Account'),
    'hello': ('落子之间，遇见乐趣。', 'A little focus. A good connection.'),
    'heroTitle': ('好棋，从\n这一手开始。', 'Great games\nstart with you.'),
    'heroBody': (
      '放慢一点，想远一步。\n和身边的人，或远方的朋友，来一局。',
      'Slow down. Think one move ahead.\nMake a little time for a friend, near or far.',
    ),
    'heroTag': ('简单规则 · 无尽可能', 'SIMPLE RULES. ENDLESS POSSIBILITIES.'),
    'friendPlay': ('与朋友对弈', 'Play with a friend'),
    'friendBody': ('一串房间码，一场好棋。', 'One room code. A great connection.'),
    'localPlay': ('同屏对弈', 'Pass & play'),
    'localBody': ('把屏幕变成你们的棋盘。', 'Two players. One happy screen.'),
    'createRoom': ('创建房间', 'Create a room'),
    'joinRoom': ('加入房间', 'Join a room'),
    'haveCode': ('已经有房间码？', 'Have a room code?'),
    'roomCode': ('六位房间码', 'Six-character room code'),
    'join': ('加入', 'Join'),
    'recentGames': ('最近的棋局', 'Your recent games'),
    'viewAll': ('查看全部', 'View all'),
    'emptyHistory': ('你的故事，从第一颗棋子开始', 'Your story starts with one stone'),
    'emptyHistoryBody': (
      '完成一局后，棋谱会保存在这里。',
      'Finished games will find a home here.',
    ),
    'startPlaying': ('开始对弈', 'Let’s play'),
    'allGames': ('全部棋局', 'All games'),
    'localGames': ('同屏', 'Pass & play'),
    'onlineGames': ('好友', 'With friends'),
    'historySubtitle': (
      '每一局，都值得回味。',
      'Every game has a story worth revisiting.',
    ),
    'continueGame': ('继续棋局', 'Continue your game'),
    'unfinished': ('还有一局，等你落子', 'Your next move is waiting'),
    'moves': ('{n} 手', '{n} moves'),
    'round': ('第 {n} 局', 'Round {n}'),
    'localMatch': ('同屏对弈', 'Pass & play'),
    'friendMatch': ('好友对弈', 'Friendly game'),
    'rules': ('15 × 15 · 自由五子棋', '15 × 15 · Freestyle'),
    'rulesTitle': ('五颗连成一线，即可获胜', 'Five in a row. That’s the game.'),
    'rulesBody': (
      '黑棋先行，双方轮流落子。横、竖或斜向连续五颗及以上即获胜，不设禁手。',
      'Black plays first. Take turns placing a stone. Five or more in a horizontal, vertical, or diagonal line wins. No forbidden moves.',
    ),
    'black': ('黑棋', 'Black'),
    'white': ('白棋', 'White'),
    'empty': ('空位', 'Empty'),
    'you': ('你', 'You'),
    'yourTurn': ('轮到你了', 'Your move'),
    'theirTurn': ('静候对方落子', 'Their move'),
    'blackTurn': ('轮到黑棋', 'Black to play'),
    'whiteTurn': ('轮到白棋', 'White to play'),
    'blackWon': ('黑棋获胜', 'Black wins'),
    'whiteWon': ('白棋获胜', 'White wins'),
    'draw': ('棋逢对手，和棋', 'A well-matched draw'),
    'interrupted': ('棋局已中断', 'Game interrupted'),
    'gameOver': ('这一局，落定。', 'A game well played.'),
    'finished': ('已结束', 'Finished'),
    'inProgress': ('进行中', 'In progress'),
    'resignation': ('对方认输', 'By resignation'),
    'board': ('五子棋棋盘', 'Gomoku board'),
    'cell': ('{point}，{stone}', '{point}, {stone}'),
    'placeStone': ('确认落子', 'Place stone'),
    'selectPoint': ('轻点棋盘，预选落子位置', 'Tap the board to choose your move'),
    'selectedPoint': ('已选 {point}', '{point} selected'),
    'keyboardHint': ('方向键选择位置，Enter 落子', 'Arrow keys to move. Enter to place.'),
    'undo': ('悔棋', 'Undo'),
    'newGame': ('重新开局', 'New game'),
    'restartTitle': ('开始新的一局？', 'Start a new game?'),
    'restartBody': (
      '当前棋局会保存为中断棋谱。',
      'Your current game will be saved as interrupted.',
    ),
    'cancel': ('取消', 'Cancel'),
    'confirm': ('确定', 'Confirm'),
    'back': ('返回', 'Back'),
    'replay': ('复盘', 'Replay'),
    'replaySubtitle': (
      '重走每一步，发现新的可能。',
      'Revisit each move. Discover a new perspective.',
    ),
    'firstMove': ('回到开局', 'First position'),
    'previousMove': ('上一步', 'Previous move'),
    'nextMove': ('下一步', 'Next move'),
    'lastMove': ('最后一手', 'Last position'),
    'autoPlay': ('自动播放', 'Play replay'),
    'pause': ('暂停', 'Pause'),
    'moveProgress': ('第 {n} / {total} 手', 'Move {n} of {total}'),
    'waitingFriend': ('留个位置，等你来。', 'A seat saved for a friend.'),
    'waitingBody': (
      '把房间码分享给朋友，准备好就开局。',
      'Share your room code. When you’re both ready, it’s game on.',
    ),
    'shareCode': ('复制房间码', 'Copy room code'),
    'shareLink': ('复制邀请链接', 'Copy invite link'),
    'copied': ('已复制，分享给朋友吧', 'Copied. Send it to a friend.'),
    'inviteFriend': ('邀请朋友', 'Invite a friend'),
    'waitingSeat': ('等待朋友加入', 'Waiting for a friend'),
    'host': ('房主', 'Host'),
    'ready': ('准备好了', 'I’m ready'),
    'isReady': ('已准备', 'Ready'),
    'notReady': ('未准备', 'Not ready'),
    'online': ('在线', 'Online'),
    'offline': ('暂时离线', 'Away'),
    'connected': ('云端已就绪', 'Ready to connect'),
    'offlineAvailable': ('随时同屏开玩', 'Pass & play, anytime'),
    'connecting': ('正在连接服务…', 'Connecting…'),
    'privateAccountNotice': (
      '使用管理员提供的账号登录后与好友对弈。本地双人无需登录。',
      'Sign in with an account provided by the host to play online. Local play needs no account.',
    ),
    'error.login_required': ('请先登录后再加入好友对弈。', 'Sign in to play with a friend.'),
    'error.account_not_allowed': (
      '此账号无法访问这个私人服务，请联系管理员。',
      'This account cannot access this private server. Contact the host.',
    ),
    'error.feature_disabled': (
      '此服务未开放该功能。',
      'This feature is unavailable on this server.',
    ),
    'reconnecting': ('正在重新连接…', 'Reconnecting…'),
    'reconnect': ('重新连接', 'Reconnect'),
    'paused': ('棋局已暂停', 'Game paused'),
    'disconnectBody': (
      '等待玩家返回，棋局将保留 {seconds} 秒。',
      'Waiting for a player to return. The game is held for {seconds}s.',
    ),
    'resign': ('认输', 'Resign'),
    'resignTitle': ('结束这一局？', 'Resign this game?'),
    'resignBody': (
      '认输后，对方获胜，棋谱会自动保存。',
      'Your friend will win and the game will be saved.',
    ),
    'leaveRoom': ('离开房间', 'Leave room'),
    'leaveTitle': ('离开这个房间？', 'Leave this room?'),
    'leaveBody': (
      '进行中的棋局会按认输结束。',
      'If a game is in progress, leaving counts as resigning.',
    ),
    'undoRequest': ('申请悔棋', 'Request undo'),
    'undoWaiting': ('已申请悔棋，等待朋友同意', 'Undo requested. Waiting for your friend.'),
    'undoIncoming': ('朋友想悔一步棋', 'Your friend would like an undo'),
    'undoExplanation': (
      '同意后，将回到对方最近一次落子之前。',
      'Accepting returns the game to before their last move.',
    ),
    'accept': ('同意', 'Accept'),
    'decline': ('拒绝', 'Decline'),
    'rematch': ('再来一局', 'Play again'),
    'rematchWaiting': ('等待朋友再来一局', 'Waiting for a rematch'),
    'closedRoom': ('房间已结束', 'This room has closed'),
    'returnHome': ('回到首页', 'Back to home'),
    'lobbyTitle': ('好朋友，好对手。', 'Good friends. Great opponents.'),
    'lobbyBody': (
      '创建专属房间，或输入朋友分享的房间码。',
      'Create your own room, or enter a code from a friend.',
    ),
    'nickname': ('怎么称呼你', 'Your nickname'),
    'nicknameHint': ('给自己取个名字', 'Choose a name'),
    'save': ('保存', 'Save'),
    'guest': ('游客', 'Guest'),
    'accountTitle': ('每一步，都跟着你。', 'Your games, wherever you go.'),
    'accountBody': (
      '登录账户，让棋谱在你的设备之间同步。',
      'Sign in to keep your games together across devices.',
    ),
    'guestNotice': (
      '游客也能开玩。注册或登录后，本机游客棋谱会合并到你的账户。',
      'Guests can play too. When you sign in, your guest games will join your account.',
    ),
    'login': ('登录', 'Sign in'),
    'register': ('注册账户', 'Create account'),
    'email': ('邮箱地址', 'Email address'),
    'password': ('密码', 'Password'),
    'passwordHint': ('至少 8 个字符', 'At least 8 characters'),
    'showPassword': ('显示密码', 'Show password'),
    'hidePassword': ('隐藏密码', 'Hide password'),
    'forgotPassword': ('忘记密码', 'Forgot password?'),
    'verificationCode': ('邮件验证码', 'Email verification code'),
    'verificationBody': (
      '验证码已发送到你的邮箱，请查收。',
      'Check your inbox for a verification code.',
    ),
    'sendCode': ('发送验证码', 'Send code'),
    'completeRegistration': ('完成注册', 'Create account'),
    'resetPassword': ('重置密码', 'Reset password'),
    'resetDone': (
      '密码已更新，请使用新密码登录。',
      'Password updated. Sign in with your new password.',
    ),
    'logout': ('退出登录', 'Sign out'),
    'logoutTitle': ('退出当前账户？', 'Sign out of your account?'),
    'logoutBody': (
      '棋谱会保留在账户中，重新登录即可查看。',
      'Your games stay with your account. Sign in again to see them.',
    ),
    'sync': ('同步棋谱', 'Sync games'),
    'syncing': ('正在同步…', 'Syncing…'),
    'synced': ('棋谱已同步', 'Games are up to date'),
    'syncPending': ('暂未同步，棋谱已保存在本机', 'Saved on this device. Sync is pending.'),
    'accountActiveRoom': (
      '先结束或离开房间，再切换账户或昵称。',
      'Finish or leave your room before changing your account or nickname.',
    ),
    'appearance': ('外观', 'Appearance'),
    'appearanceBody': ('选一种颜色，找到舒服的节奏。', 'Find your color. Set your own pace.'),
    'theme': ('显示模式', 'Appearance'),
    'system': ('跟随系统', 'System'),
    'light': ('浅色', 'Light'),
    'dark': ('深色', 'Dark'),
    'accent': ('主题色', 'Your color'),
    'iris': ('鸢尾紫', 'Iris'),
    'sage': ('鼠尾草绿', 'Sage'),
    'peach': ('杏桃', 'Peach'),
    'ocean': ('海蓝', 'Ocean'),
    'dynamicColor': ('系统动态配色', 'Dynamic colors'),
    'dynamicColorBody': (
      '在支持的设备上，使用系统主题色',
      'Use your system palette on supported devices',
    ),
    'language': ('语言', 'Language'),
    'zh': ('简体中文', '简体中文'),
    'en': ('English', 'English'),
    'playPreferences': ('对弈习惯', 'Your playing style'),
    'sound': ('落子声音', 'Stone sounds'),
    'haptics': ('触感反馈', 'Haptic feedback'),
    'confirmTouch': ('触屏落子确认', 'Confirm touch moves'),
    'confirmTouchBody': (
      '先预选位置，再确认落子',
      'Choose a position before placing a stone',
    ),
    'moveNumbers': ('显示落子顺序', 'Show move numbers'),
    'reduceMotion': ('减少动画', 'Reduce motion'),
    'reduceMotionBody': ('使用更轻的过渡效果', 'Keep transitions gentle'),
    'about': ('关于', 'About'),
    'aboutBody': (
      'Gomoku 1.2.1\n给专注一点空间，给朋友一点时间。',
      'Gomoku 1.2.1\nA little space to focus. A little time for friends.',
    ),
    'storageWarning': (
      '当前浏览器无法长期保存棋谱。关闭页面前，请登录并完成同步。',
      'This browser cannot keep games permanently. Sign in and sync before closing.',
    ),
    'loading': ('稍等片刻…', 'Just a moment…'),
    'retry': ('重试', 'Try again'),
    'savedLocally': ('棋谱已自动保存', 'Game saved automatically'),
    'noRecord': ('没有找到这份棋谱', 'This game could not be found'),
    'today': ('今天', 'Today'),
    'yesterday': ('昨天', 'Yesterday'),
    'error.generic': (
      '暂时无法完成操作，请稍后再试。',
      'Something went wrong. Please try again.',
    ),
    'error.service_unavailable': (
      '暂时连不上服务，请稍后再试。同屏对弈仍可使用。',
      'We couldn’t connect. Try again shortly. Pass & play is still available.',
    ),
    'error.unauthenticated': (
      '登录状态已失效，请重新登录。',
      'Your session has expired. Please sign in again.',
    ),
    'error.invalid_credentials': (
      '邮箱或密码不正确，请检查后重试。',
      'That email or password doesn’t look right.',
    ),
    'error.invalid_verification': (
      '验证码或密码不符合要求，请检查后重试。',
      'Check your verification code and password, then try again.',
    ),
    'error.invalid_request': (
      '请检查填写的内容。',
      'Please check the information you entered.',
    ),
    'error.invalid_nickname': (
      '昵称需要 1–24 个字符。',
      'Choose a nickname with 1–24 characters.',
    ),
    'error.room_not_found': (
      '没有找到这个房间，请检查房间码。',
      'Room not found. Check the code and try again.',
    ),
    'error.invalid_room_code': (
      '请输入正确的六位房间码。',
      'Enter a valid six-character room code.',
    ),
    'error.room_expired': (
      '这个房间已结束，请创建新的房间。',
      'This room has expired. Create a new one.',
    ),
    'error.room_full': ('这个房间已经坐满了。', 'Both seats in this room are taken.'),
    'error.active_room': (
      '你还有一个房间，请先返回并结束或离开。',
      'You already have a room. Finish or leave it first.',
    ),
    'error.stale_revision': (
      '棋局已更新，请重新确认操作。',
      'The game has updated. Please confirm your move again.',
    ),
    'error.not_your_turn': ('还没轮到你，请等待对方落子。', 'It’s your friend’s turn.'),
    'error.occupied': ('这里已经有一颗棋子了。', 'There’s already a stone here.'),
    'error.opponent_disconnected': (
      '等待双方连接恢复后即可继续。',
      'The game will continue when both players reconnect.',
    ),
    'error.rate_limited': (
      '操作有些频繁，请稍等再试。',
      'A little too fast. Please wait a moment.',
    ),
    'error.storage_unavailable': (
      '暂时无法保存棋谱，请勿关闭应用。',
      'We couldn’t save this game. Please keep the app open.',
    ),
    'error.account_required': ('登录后即可同步棋谱。', 'Sign in to sync your games.'),
    'error.undo_pending': (
      '请先处理当前的悔棋申请。',
      'Please finish the current undo request first.',
    ),
    'error.not_a_player': (
      '你不在这个房间中，请通过房间码加入。',
      'Join this room using its room code.',
    ),
    'error.game_not_started': (
      '双方准备好后即可开局。',
      'The game starts when both players are ready.',
    ),
    'error.please_wait': ('正在处理，请稍等。', 'One moment, please.'),
  };
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension StringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
