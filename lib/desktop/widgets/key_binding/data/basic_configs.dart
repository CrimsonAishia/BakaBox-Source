import '../views/key_binding_list_view.dart' show CfgCategory, CfgItem;

final List<CfgCategory> basicConfigCategories = [
  CfgCategory('武器类', [
    CfgItem('购买MP9', 'mp9;c_mp9;ms_mp9;sm_mp9'),
    CfgItem('购买MP7', 'mp7;c_mp7;ms_mp7;sm_mp7'),
    CfgItem('购买MP5SD', 'mp5sd;c_mp5sd;ms_mp5sd;sm_mp5sd'),
    CfgItem('购买MAC10', 'mac10;c_mac10;ms_mac10;sm_mac10'),
    CfgItem('购买P90', 'p90;c_p90;ms_p90;sm_p90'),
    CfgItem('购买野牛', 'bizon;c_bizon;ms_bizon;sm_bizon'),
    CfgItem('购买M249', 'm249;c_m249;ms_m249;sm_m249'),
    CfgItem('购买内格夫', 'negev;c_negev;ms_negev;sm_negev'),
    CfgItem('购买AK47', 'ak47;c_ak47;ms_ak47;sm_ak47'),
    CfgItem('购买M4A4', 'm4a4;c_m4a4;ms_m4a4;sm_m4a4'),
    CfgItem(
      '购买M4A1-S',
      'm4a1_silencer;c_m4a1_silencer;ms_m4a1_silencer;sm_m4a1_silencer',
    ),
    CfgItem('购买Famas', 'famas;c_famas;ms_famas;sm_famas'),
    CfgItem('购买SG556', 'sg556;c_sg556;ms_sg556;sm_sg556'),
    CfgItem('购买AUG', 'aug;c_aug;ms_aug;sm_aug'),
    CfgItem('购买Galilar', 'galilar;c_galilar;ms_galilar;sm_galilar'),
    CfgItem('购买新星', 'nova;c_nova;ms_nova;sm_nova'),
    CfgItem('购买XM1014', 'xm1014;c_xm1014;ms_xm1014;sm_xm1014'),
    CfgItem('购买匪喷', 'sawedoff;c_sawedoff;ms_sawedoff;sm_sawedoff'),
    CfgItem('购买警喷', 'mag7;c_mag7;ms_mag7;sm_mag7'),
    CfgItem('购买SSG08', 'ssg08;c_ssg08;ms_ssg08;sm_ssg08'),
    CfgItem('购买AWP', 'awp;c_awp;ms_awp;sm_awp'),
    CfgItem('购买G3SG1', 'g3sg1;c_g3sg1;ms_g3sg1;sm_g3sg1'),
    CfgItem('购买SCAR20', 'scar20;c_scar20;ms_scar20;sm_scar20'),
    CfgItem('购买沙鹰', 'deagle;c_deagle;ms_deagle;sm_deagle'),
    CfgItem('购买R8', 'revolver;c_revolver;ms_revolver;sm_revolver'),
    CfgItem('购买格洛克', 'glock;c_glock;ms_glock;sm_glock'),
    CfgItem('购买双枪', 'elite;c_elite;ms_elite;sm_elite'),
    CfgItem(
      '购买USP',
      'usp_sliencer;c_usp_sliencer;ms_usp_sliencer;sm_usp_sliencer',
    ),
    CfgItem('购买P250', 'p250;c_p250;ms_p250;sm_p250'),
    CfgItem('购买CZ-75', 'cz75a;c_cz75a;ms_cz75a;sm_cz75a'),
  ]),
  CfgCategory('道具类', [
    CfgItem('购买烟雾弹', 'buy !smokegrenade'),
    CfgItem('购买手雷', 'say !he'),
    CfgItem('购买燃烧弹', 'say !molotov'),
    CfgItem('购买闪光弹', 'buy !flashbang'),
    CfgItem('开关夜视仪', 'toggle mat_fullbright'),
    CfgItem('购买血针', 'xz;c_xz;ms_health;sm_xz'),
    CfgItem('购买护甲', 'kevlar;c_kevlar;ms_kevlar;sm_kevlar'),
    CfgItem('冰冻弹', 'c_ice'),
  ]),
  CfgCategory('通用', [
    CfgItem(
      '开启第三人称',
      '+tp',
      description: '常规的第三人称视角，按下时开启，再次按下关闭。',
      fullScript: '''//freecam and tp 
alias cam_setting_tp "c_thirdpersonshoulder 1;c_thirdpersonshoulderheight 30;c_thirdpersonshoulderoffset 0;c_thirdpersonshoulderaimdist 999;cam_idealdist 180;cam_collision 0"

//freecam --> +tp
alias "cs_chasecam_freecam" "cs_aliasthird_freecam"
alias "cs_aliasthird_freecam" "thirdperson; cam_setting_tp; alias cs_chasecam_freecam ccs_aliasfirst_freecam"
alias "ccs_aliasfirst_freecam" "firstperson; alias cs_chasecam_freecam cs_aliasthird_freecam"

alias +tp_magnifier "cs_chasecam_freecam; _freecamup; _freecamdn; cam_collision 0"
alias -tp_magnifier "cs_chasecam_freecam; -keys_mouse"

//tp --> -tp
alias cs_chasecam_tp "cs_aliasthird_tp"
alias cs_aliasthird_tp "thirdperson;cam_setting_tp;alias cs_chasecam_tp cs_aliasfirst_tp"
alias cs_aliasfirst_tp "firstperson;alias cs_chasecam_tp cs_aliasthird_tp"

alias "+tp" "+tp_magnifier"
alias "-tp" "cs_chasecam_tp;-keys_mouse"

bind "{{KEY:按键}}" "+tp"
c_thirdpersonshoulder 1; cam_idealyaw 0; cam_idealpitch 0; cam_collision 0
c_mindistance -999999; c_maxdistance 999999''',
    ),
    CfgItem(
      '三段式第三人称',
      'third_p1',
      description: '1段常规第三人称锁定，2段解锁鼠标可转动人物视角，3段恢复第一人称。',
      fullScript: '''alias third_p1 "thirdperson; bind {{KEY:按键}} third_p2"
alias third_p2 "thirdperson_mayamode; bind {{KEY:按键}} third_p3"
alias third_p3 "thirdperson_mayamode; firstperson; bind {{KEY:按键}} third_p1"
bind "{{KEY:按键}}" "third_p1"''',
    ),
    CfgItem('开关地图滤镜', 'toggle r_csgo_postprocess_enable'),
    CfgItem('开关地图特效', 'toggle r_drawparticles'),
    CfgItem('画面亮度调整', 'toggle r_fullscreen_gamma 1 1.5 2 2.5 3'),
    CfgItem('隐藏腿部模型', 'say !hidebody'),
    CfgItem('传送到复活点', 'say !ztele'),
    CfgItem('屏蔽好友', 'c_hidesteamfriends'),
    CfgItem('屏蔽白名单', 'c_hidefriends'),
  ]),
];
