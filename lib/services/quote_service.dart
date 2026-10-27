import 'package:hive/hive.dart';
import '../models/quote.dart';

class QuoteService {
  static final QuoteService _instance = QuoteService._internal();
  factory QuoteService() => _instance;
  QuoteService._internal();

  final List<Quote> _customQuotes = [];

  Box<Quote>? _quoteBox;

  void init(Box<Quote> box) {
    _quoteBox = box;
    _customQuotes.addAll(box.values.where((q) => !q.id.startsWith('builtin_')));
  }

  List<Quote> get allQuotes => [
    ...builtInQuotes,
    ..._customQuotes,
  ];

  List<Quote> get builtInQuotes {
    final now = DateTime.now();
    return [
      Quote(id: 'builtin_001', text: '生命好在无意义，才容得下各自赋予意义。', author: '木心', category: '哲思', createdAt: now),
      Quote(id: 'builtin_002', text: '你不愿意种花，你说，我不愿看见它一点点凋落。是的，为了避免结束，你避免了一切开始。', author: '顾城', category: '哲思', createdAt: now),
      Quote(id: 'builtin_003', text: '生活不是我们活过的日子，而是我们记住的日子。', author: '马尔克斯', category: '生活', createdAt: now),
      Quote(id: 'builtin_004', text: '我们终其一生，就是要摆脱他人的期待，找到真正的自己。', author: null, source: '《无声告白》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_005', text: '世界上只有一种真正的英雄主义，那就是在认清生活的真相后依然热爱生活。', author: '罗曼·罗兰', category: '生活', createdAt: now),
      Quote(id: 'builtin_006', text: '我年华虚度，空有一身疲倦。', author: '海子', category: '孤独', createdAt: now),
      Quote(id: 'builtin_007', text: '你说的曙光究竟是什么意思？', author: '海子', category: '哲思', createdAt: now),
      Quote(id: 'builtin_008', text: '生如夏花之绚烂，死如秋叶之静美。', author: '泰戈尔', category: '哲思', createdAt: now),
      Quote(id: 'builtin_009', text: '在这个世界上，所有真性情的人，想法总是与众不同。', author: '沈从文', category: '生活', createdAt: now),
      Quote(id: 'builtin_010', text: '我行过许多地方的桥，看过许多次数的云，喝过许多种类的酒，却只爱过一个正当最好年龄的人。', author: '沈从文', category: '爱情', createdAt: now),
      Quote(id: 'builtin_011', text: '凡事都有偶然的凑巧，结果却又如宿命的必然。', author: '沈从文', category: '哲思', createdAt: now),
      Quote(id: 'builtin_012', text: '每想你一次，天上飘落一粒沙，从此形成了撒哈拉。', author: '三毛', category: '爱情', createdAt: now),
      Quote(id: 'builtin_013', text: '一个人至少拥有一个梦想，有一个理由去坚强。心若没有栖息的地方，到哪里都是在流浪。', author: '三毛', category: '旅行', createdAt: now),
      Quote(id: 'builtin_014', text: '岁月极美，在于它必然的流逝。春花、秋月、夏日、冬雪。', author: '三毛', category: '时间', createdAt: now),
      Quote(id: 'builtin_015', text: '刻意去找的东西，往往是找不到的。天下万物的来和去，都有他的时间。', author: '三毛', category: '时间', createdAt: now),
      Quote(id: 'builtin_016', text: '活着本身就是一种精彩。', author: null, source: '《活着》', category: '生活', createdAt: now),
      Quote(id: 'builtin_017', text: '没有什么比时间更有说服力了，因为时间无需通知我们就可以改变一切。', author: '余华', category: '时间', createdAt: now),
      Quote(id: 'builtin_018', text: '人是为活着本身而活着的，而不是为了活着之外的任何事物所活着。', author: '余华', category: '哲思', createdAt: now),
      Quote(id: 'builtin_019', text: '死亡不是失去了生命，而是走出了时间。', author: '余华', category: '时间', createdAt: now),
      Quote(id: 'builtin_020', text: '我什么都没忘，只是有些事只适合收藏。', author: '史铁生', category: '孤独', createdAt: now),
      Quote(id: 'builtin_021', text: '人的命就像这琴弦，拉紧了才能弹好，弹好了就够了。', author: '史铁生', category: '哲思', createdAt: now),
      Quote(id: 'builtin_022', text: '春天是一点一点化开的。', author: '迟子建', category: '自然', createdAt: now),
      Quote(id: 'builtin_023', text: '我用什么才能留住你？我给你瘦落的街道、绝望的落日、荒郊的月亮。', author: '博尔赫斯', category: '爱情', createdAt: now),
      Quote(id: 'builtin_024', text: '我心里一直都在暗暗设想，天堂应该是图书馆的模样。', author: '博尔赫斯', category: '哲思', createdAt: now),
      Quote(id: 'builtin_025', text: '时间是构成我的物质。时间是带走我的河流，但我即是河流。', author: '博尔赫斯', category: '时间', createdAt: now),
      Quote(id: 'builtin_026', text: '我假装是要看看，除了故事里的人，是否还有人惦记自己。', author: '博尔赫斯', category: '孤独', createdAt: now),
      Quote(id: 'builtin_027', text: '在隆冬，我终于知道，我身上有一个不可战胜的夏天。', author: '加缪', category: '生活', createdAt: now),
      Quote(id: 'builtin_028', text: '一切伟大的行动和思想，都有一个微不足道的开始。', author: '加缪', category: '哲思', createdAt: now),
      Quote(id: 'builtin_029', text: '重要的不是治愈，而是带着病痛活下去。', author: '加缪', category: '哲思', createdAt: now),
      Quote(id: 'builtin_030', text: '所谓世人，不就是你吗？', author: '太宰治', category: '哲思', createdAt: now),
      Quote(id: 'builtin_031', text: '一夜之间，我心竟判若两人。', author: '太宰治', category: '孤独', createdAt: now),
      Quote(id: 'builtin_032', text: '生而为人，我很抱歉。', author: '太宰治', category: '孤独', createdAt: now),
      Quote(id: 'builtin_033', text: '若能避开猛烈的欢喜，自然也不会有悲痛的来袭。', author: '太宰治', category: '爱情', createdAt: now),
      Quote(id: 'builtin_034', text: '胆小鬼连幸福都会害怕，碰到棉花都会受伤。', author: '太宰治', category: '孤独', createdAt: now),
      Quote(id: 'builtin_035', text: '是谁来自山川湖海，却囿于昼夜、厨房与爱。', author: null, source: '万能青年旅店《揪心的玩笑与漫长的白日梦》', category: '生活', createdAt: now),
      Quote(id: 'builtin_036', text: '春风再美也比不上你的笑，没见过你的人不会明了。', author: null, source: '李宗盛《鬼迷心窍》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_037', text: '越过山丘，才发现无人等候。', author: null, source: '李宗盛《山丘》', category: '孤独', createdAt: now),
      Quote(id: 'builtin_038', text: '我曾经跨过山和大海，也穿过人山人海。', author: null, source: '朴树《平凡之路》', category: '旅行', createdAt: now),
      Quote(id: 'builtin_039', text: '直到看见平凡，才是唯一的答案。', author: null, source: '朴树《平凡之路》', category: '生活', createdAt: now),
      Quote(id: 'builtin_040', text: '生活像一把无情刻刀，改变了我们模样。', author: null, source: '筷子兄弟《老男孩》', category: '时间', createdAt: now),
      Quote(id: 'builtin_041', text: '当完成了童年的理想，童年又变成了理想。', author: null, source: '痛仰乐队', category: '时间', createdAt: now),
      Quote(id: 'builtin_042', text: '我想和你互相浪费，一起虚度短的沉默，长的无意义。', author: null, source: '程璧《我想和你虚度时光》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_043', text: '人生就是一列开往坟墓的列车，路途上会有很多站，很难有人可以自始至终陪着走完。', author: null, source: '《千与千寻》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_044', text: '我不知道将去何方，但我已在路上。', author: null, source: '《千与千寻》', category: '旅行', createdAt: now),
      Quote(id: 'builtin_045', text: '这短短的一生，我们最终都会失去。你不妨大胆一些，爱一个人，攀一座山，追一个梦。', author: null, source: '《大鱼海棠》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_046', text: '你看，那个人好像一条狗。', author: null, source: '《大话西游》', category: '生活', createdAt: now),
      Quote(id: 'builtin_047', text: '如果记忆是一个罐头，我希望它永远不会过期。', author: null, source: '《重庆森林》', category: '时间', createdAt: now),
      Quote(id: 'builtin_048', text: '其实了解一个人并不代表什么，人是会变的，今天他喜欢凤梨，明天他可以喜欢别的。', author: null, source: '《重庆森林》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_049', text: '不如我们从头来过。', author: null, source: '《春光乍泄》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_050', text: '人生若无悔，那该多无趣。', author: null, source: '《一代宗师》', category: '生活', createdAt: now),
      Quote(id: 'builtin_051', text: '念念不忘，必有回响。', author: null, source: '《一代宗师》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_052', text: '一个人可以被毁灭，但不能被打败。', author: '海明威', category: '生活', createdAt: now),
      Quote(id: 'builtin_053', text: '世界以痛吻我，要我报之以歌。', author: '泰戈尔', category: '哲思', createdAt: now),
      Quote(id: 'builtin_054', text: '黑夜给了我黑色的眼睛，我却用它寻找光明。', author: '顾城', category: '哲思', createdAt: now),
      Quote(id: 'builtin_055', text: '我只不过为了储存足够的爱，足够的温柔和狡猾，以防万一，醒来就遇见你。', author: '顾城', category: '爱情', createdAt: now),
      Quote(id: 'builtin_056', text: '草在结它的种子，风在摇它的叶子。我们站着，不说话，就十分美好。', author: '顾城', category: '自然', createdAt: now),
      Quote(id: 'builtin_057', text: '字迹已模糊，因为思念的缘故。', author: '顾城', category: '爱情', createdAt: now),
      Quote(id: 'builtin_058', text: '对于世界，我永远是个陌生人。', author: '北岛', category: '孤独', createdAt: now),
      Quote(id: 'builtin_059', text: '你没有如期归来，而这正是离别的意义。', author: '北岛', category: '孤独', createdAt: now),
      Quote(id: 'builtin_060', text: '那时我们有梦，关于文学，关于爱情，关于穿越世界的旅行。如今我们深夜饮酒，杯子碰到一起，都是梦破碎的声音。', author: '北岛', category: '哲思', createdAt: now),
      Quote(id: 'builtin_061', text: '一个人的行走范围，就是他的世界。', author: '北岛', category: '旅行', createdAt: now),
      Quote(id: 'builtin_062', text: '愿你被很多人爱，如果没有，愿你在寂寞中学会宽容。', author: '刘瑜', category: '生活', createdAt: now),
      Quote(id: 'builtin_063', text: '人一切的痛苦，本质上都是对自己无能的愤怒。', author: '王小波', category: '哲思', createdAt: now),
      Quote(id: 'builtin_064', text: '生活就是个缓慢受锤的过程，人一天天老下去，奢望也一天天消失。', author: '王小波', category: '生活', createdAt: now),
      Quote(id: 'builtin_065', text: '我把我整个灵魂都给你，连同它的怪癖，耍小脾气，忽明忽暗，一千八百种坏毛病。它真讨厌，只有一点好，爱你。', author: '王小波', category: '爱情', createdAt: now),
      Quote(id: 'builtin_066', text: '不管我本人多么平庸，我总觉得对你的爱很美。', author: '王小波', category: '爱情', createdAt: now),
      Quote(id: 'builtin_067', text: '一想到你，我这张丑脸上就泛起微笑。', author: '王小波', category: '爱情', createdAt: now),
      Quote(id: 'builtin_068', text: '我会不爱你吗？不爱你？不会。爱你就像爱生命。', author: '王小波', category: '爱情', createdAt: now),
      Quote(id: 'builtin_069', text: '风后面是风，天空上面是天空，道路前面还是道路。', author: '海子', category: '自然', createdAt: now),
      Quote(id: 'builtin_070', text: '你来人间一趟，你要看看太阳。', author: '海子', category: '生活', createdAt: now),
      Quote(id: 'builtin_071', text: '此后如竟没有炬火，我便是唯一的光。', author: '鲁迅', category: '哲思', createdAt: now),
      Quote(id: 'builtin_072', text: '无穷的远方，无数的人们，都和我有关。', author: '鲁迅', category: '哲思', createdAt: now),
      Quote(id: 'builtin_073', text: '我们好像在池塘的水底，从一个月亮走向另一个月亮。', author: '王小波', category: '孤独', createdAt: now),
      Quote(id: 'builtin_074', text: '每个人心里都有一团火，路过的人只看到烟。', author: null, source: '梵高', category: '孤独', createdAt: now),
      Quote(id: 'builtin_075', text: '如果你来访我，我不在，请和我门外的花坐一会儿。', author: '汪曾祺', category: '自然', createdAt: now),
      Quote(id: 'builtin_076', text: '一定要爱着点什么，恰似草木对光阴的钟情。', author: '汪曾祺', category: '自然', createdAt: now),
      Quote(id: 'builtin_077', text: '四方食事，不过一碗人间烟火。', author: '汪曾祺', category: '生活', createdAt: now),
      Quote(id: 'builtin_078', text: '黄油饼是甜的，混着的眼泪是咸的。就像人生，交织着各种复杂而美好的味道。', author: '汪曾祺', category: '生活', createdAt: now),
      Quote(id: 'builtin_079', text: '有些人能感受雨，而其他人则只是被淋湿。', author: '鲍勃·迪伦', category: '自然', createdAt: now),
      Quote(id: 'builtin_080', text: '当我们仰望星空时，我们其实是在回望过去。', author: null, source: '佚名', category: '时间', createdAt: now),
      Quote(id: 'builtin_081', text: '你要做一个不动声色的大人了。不准情绪化，不准偷偷想念，不准回头看。', author: '村上春树', category: '生活', createdAt: now),
      Quote(id: 'builtin_082', text: '哪里会有人喜欢孤独，不过是不喜欢失望罢了。', author: '村上春树', category: '孤独', createdAt: now),
      Quote(id: 'builtin_083', text: '不必太纠结于当下，也不必太忧虑未来，人生没有无用的经历。', author: '村上春树', category: '生活', createdAt: now),
      Quote(id: 'builtin_084', text: '看海看久了想见人，见人见多了想看海。', author: '村上春树', category: '旅行', createdAt: now),
      Quote(id: 'builtin_085', text: '痛苦来临时不要总问：为什么偏偏是我？因为快乐降临时你可没有问过这个问题。', author: null, source: '佚名', category: '哲思', createdAt: now),
      Quote(id: 'builtin_086', text: '该相见的人，总有一天会相见的。', author: null, source: '《请回答1988》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_087', text: '听说神不能无处不在，所以创造了妈妈。', author: null, source: '《请回答1988》', category: '生活', createdAt: now),
      Quote(id: 'builtin_088', text: '小时候家里住着超人，他是个能够修理世上所有东西的百战天龙。', author: null, source: '《请回答1988》', category: '生活', createdAt: now),
      Quote(id: 'builtin_089', text: '大人们只是在忍，只是在忙着大人们的事，只是在用故作坚强来承担年龄的重担。', author: null, source: '《请回答1988》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_090', text: '不管你是谁，在世上的某个地方，总有一个人是为你而存在的。', author: null, source: '《蓝色大门》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_091', text: '小步紧跑去迎接一个人的快乐，是只有童年才有的特权。', author: '张爱玲', category: '时间', createdAt: now),
      Quote(id: 'builtin_092', text: '因为爱过，所以慈悲；因为懂得，所以宽容。', author: '张爱玲', category: '爱情', createdAt: now),
      Quote(id: 'builtin_093', text: '你如果认识从前的我，也许你会原谅现在的我。', author: '张爱玲', category: '时间', createdAt: now),
      Quote(id: 'builtin_094', text: '孤独的人有他们自己的泥沼。', author: '张爱玲', category: '孤独', createdAt: now),
      Quote(id: 'builtin_095', text: '山河远阔，人间烟火，无一是你，无一不是你。', author: null, source: '春和《江海共余生》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_096', text: '星星发亮是为了让每一个人有一天都能找到属于自己的星星。', author: null, source: '《小王子》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_097', text: '如果你驯化了我，我们就彼此需要了。', author: null, source: '《小王子》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_098', text: '正是你为你的玫瑰花费的时间，才使你的玫瑰变得如此重要。', author: null, source: '《小王子》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_099', text: '所有的大人都曾经是小孩，虽然，只有少数的人记得。', author: null, source: '《小王子》', category: '时间', createdAt: now),
      Quote(id: 'builtin_100', text: '沙漠之所以美丽，是因为在它的某个角落隐藏着一口井。', author: null, source: '《小王子》', category: '旅行', createdAt: now),
      Quote(id: 'builtin_101', text: '没有不可治愈的伤痛，没有不能结束的沉沦，所有失去的，会以另一种方式归来。', author: '约翰·肖尔斯', category: '生活', createdAt: now),
      Quote(id: 'builtin_102', text: '真正的自由不是你想做什么就做什么，而是你不想做什么就不做什么。', author: '康德', category: '哲思', createdAt: now),
      Quote(id: 'builtin_103', text: '相濡以沫，不如相忘于江湖。', author: '庄子', category: '哲思', createdAt: now),
      Quote(id: 'builtin_104', text: '人生天地之间，若白驹之过隙，忽然而已。', author: '庄子', category: '时间', createdAt: now),
      Quote(id: 'builtin_105', text: '只有用水将心上的雾气淘洗干净，荣光才会照亮最初的梦想。', author: null, source: '《百年孤独》', category: '哲思', createdAt: now),
      Quote(id: 'builtin_106', text: '生命中曾经有过的所有灿烂，终究都需要用寂寞来偿还。', author: null, source: '《百年孤独》', category: '孤独', createdAt: now),
      Quote(id: 'builtin_107', text: '过去都是假的，回忆是一条没有归途的路。', author: null, source: '《百年孤独》', category: '时间', createdAt: now),
      Quote(id: 'builtin_108', text: '当一个女人决定和一个男人睡觉时，就没有她跃不过去的围墙，没有她推不倒的堡垒。', author: null, source: '《霍乱时期的爱情》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_109', text: '我去旅行，是因为我决定了要去，并不是因为对风景的兴趣。', author: '马尔克斯', category: '旅行', createdAt: now),
      Quote(id: 'builtin_110', text: '趁年轻，好好利用这个机会，尽力去尝遍所有痛苦。', author: '马尔克斯', category: '生活', createdAt: now),
      Quote(id: 'builtin_111', text: '我以为爱情可以填满人生的遗憾，然而制造更多遗憾的，却偏偏是爱情。', author: '张爱玲', category: '爱情', createdAt: now),
      Quote(id: 'builtin_112', text: '孤独和发烧一样，在夜晚最盛。', author: null, source: '杜鲁门·卡波特', category: '孤独', createdAt: now),
      Quote(id: 'builtin_113', text: '我一边踉跄前行，一边重振旗鼓。', author: '太宰治', category: '生活', createdAt: now),
      Quote(id: 'builtin_114', text: '不要因为走得太远，而忘记为什么出发。', author: '纪伯伦', category: '旅行', createdAt: now),
      Quote(id: 'builtin_115', text: '眼泪是人类能制造的最小的海洋。', author: null, source: '寺山修司', category: '孤独', createdAt: now),
      Quote(id: 'builtin_116', text: '人生最好的旅行，就是你在一个陌生的地方，发现一种久违的感动。', author: null, source: '佚名', category: '旅行', createdAt: now),
      Quote(id: 'builtin_117', text: '身体和灵魂，总有一个要在路上。', author: null, source: '《罗马假日》', category: '旅行', createdAt: now),
      Quote(id: 'builtin_118', text: '我偏爱写诗的荒谬，胜过不写诗的荒谬。', author: '辛波斯卡', category: '哲思', createdAt: now),
      Quote(id: 'builtin_119', text: '你是我温暖的手套，冰冷的啤酒，带着阳光味道的衬衫，日复一日的梦想。', author: null, source: '廖一梅《恋爱的犀牛》', category: '爱情', createdAt: now),
      Quote(id: 'builtin_120', text: '你一直在练习微笑，倒不是说变成了自己讨厌的人，而是在世故中变得沉稳。', author: null, source: '佚名', category: '生活', createdAt: now),

      // ── 网易云热评 ──
      Quote(id: 'builtin_121', text: '十年前你说生如夏花般绚烂，十年后你说平凡才是唯一的答案。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_122', text: '你是我藏在循环播放里的秘密。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_123', text: '听歌的人不许掉眼泪，写歌的人不许太憔悴。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_124', text: '年轻时不要遇到太惊艳的人，不然余生都无法安宁。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_125', text: '我听过一万首歌，看过一千部电影，读过一百本书，却从未俘获一个人的心。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_126', text: '愿你余生安好，也愿我从此不扰。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_127', text: '友情其实比爱情更长久，因为我们从没想过要占有。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_128', text: '后来我发现，原来真的会有两个人，互相喜欢，互相惦念，互相忘不掉，却没有在一起。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_129', text: '你只不过是在我最脆弱的时候，给了我一个刚好路过的拥抱。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_130', text: '我们都有一个通病：安慰别人时头头是道，安慰自己时只剩苦笑。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_131', text: '人的内心不种满鲜花就会长满杂草。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_132', text: '希望听到这首歌的人，不再为情所困。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_133', text: '我坚持不和你说话，不代表我没有想你。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_134', text: '不在一起就不在一起吧，反正一辈子也没多长。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_135', text: '有些歌听前奏就红了眼眶，有些人一想起就乱了心跳。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_136', text: '最怕的是，突然听懂了某一首歌。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_137', text: '你是无意穿堂风，偏偏孤倨引山洪。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_138', text: '我为你翻山越岭，却无心看风景。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_139', text: '人一旦有了期待，就等于为自己画好了牢笼。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_140', text: '喜欢这种东西，就算捂住了嘴巴，也会从眼睛里跑出来。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_141', text: '愿你三冬暖，愿你春不寒，愿你天黑有灯下雨有伞。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_142', text: '这个世界疯狂，没人性，腐败，而你却一直清醒，温柔，一尘不染。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_143', text: '所有的晦暗都留给过往，从遇见你开始，凛冬散尽星河长明。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_144', text: '我在人间贩卖黄昏，只为收集世间温柔去见你。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),
      Quote(id: 'builtin_145', text: '山海自有归期，风雨自有相逢，意难平终将和解。', author: null, source: '网易云音乐', category: '网易云', createdAt: now),

      // ── 小红书文案 ──
      Quote(id: 'builtin_146', text: '生活不是为了赶路，而是为了感受路。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_147', text: '把期待降到最低，所有遇见都是礼物。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_148', text: '在这个快餐时代，我想和你慢慢来。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_149', text: '风吹哪页读哪页，哪页难读撕哪页。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_150', text: '别让生活的琐碎，掩盖了你眼里的光。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_151', text: '先成为自己的光，再温暖身边的人。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_152', text: '做一个内心自带光源的人，照耀自己的同时也能温暖他人。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_153', text: '日子是重复的，但快乐是自己找的。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_154', text: '零碎的岛屿终会找到海，慢慢亦漫漫。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_155', text: '爱自己是终身浪漫的开始。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_156', text: '允许一切发生，因为一切皆为风景。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_157', text: '凡是过往，皆为序章；凡是未来，皆可期待。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_158', text: '不必太在意旁人的目光，你活得漂亮就是最好的回击。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_159', text: '你在拍风景，而拍风景的人在拍你。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_160', text: '生活可以平凡，但不可以平庸。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_161', text: '去爱一个能让你做回小朋友的人，而不是总让你委屈的人。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_162', text: '慢慢理解世界，慢慢更新自己。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_163', text: '取悦自己才是生活的王道。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_164', text: '日落尤其温柔，人间皆是浪漫。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_165', text: '向内生长，向外绽放。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_166', text: '没有销声匿迹，我在热爱生活。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_167', text: '你喜欢的不是文案，是文案里写出的自己。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_168', text: '有人慌张见面，有人简单告别。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_169', text: '不做谁的公主，做自己的骑士。', author: null, source: '小红书', category: '小红书', createdAt: now),
      Quote(id: 'builtin_170', text: '请保持热爱，奔赴下一场山海。', author: null, source: '小红书', category: '小红书', createdAt: now),
    ];
  }

  List<Quote> getQuotesByCategory(String category) {
    return allQuotes.where((q) => q.category == category).toList();
  }

  Quote getDailyQuoteDetails() {
    final now = DateTime.now();
    final dayOfYear = int.parse(
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
    );
    final pool = allQuotes;
    return pool[dayOfYear % pool.length];
  }

  Future<void> addQuote(Quote quote) async {
    _customQuotes.add(quote);
    try {
      await _quoteBox?.put(quote.id, quote);
    } catch (_) {}
  }

  void deleteQuote(String id) {
    _customQuotes.removeWhere((q) => q.id == id);
    try {
      _quoteBox?.delete(id);
    } catch (_) {}
  }
}
