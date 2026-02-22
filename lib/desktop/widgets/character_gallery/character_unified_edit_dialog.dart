import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/character_gallery/character_gallery_bloc.dart';
import '../../../core/bloc/character_gallery/character_gallery_event.dart';
import '../../../core/bloc/character_gallery/character_gallery_state.dart';
import '../../../core/models/character_models.dart';
import '../../../core/utils/toast_utils.dart';
import 'character_gallery_theme.dart';
import 'character_dialogs.dart';
import 'character_edit_data_models.dart';
import 'character_spell_card_edit_dialogs.dart';
import 'character_zombie_skill_edit_dialogs.dart';
import 'preview_images_upload_widget.dart';

/// 统一编辑弹窗 - 整合所有编辑功能
class UnifiedEditDialog extends StatefulWidget {
  final CharacterModel character;
  final CharacterSubModel subModel;
  final List<SpellCard> spellCards;
  final int? pendingRequestId; // 待审核申请ID，用于修改模式
  final EditRequestDetailResponse? pendingRequestDetail; // 待审核申请详情，用于预填充

  const UnifiedEditDialog({
    super.key,
    required this.character,
    required this.subModel,
    required this.spellCards,
    this.pendingRequestId,
    this.pendingRequestDetail,
  });

  /// 是否为修改模式（修改待审核申请）
  bool get isEditMode => pendingRequestId != null;

  @override
  State<UnifiedEditDialog> createState() => _UnifiedEditDialogState();
}

class _UnifiedEditDialogState extends State<UnifiedEditDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _editReasonController;

  // 角色介绍
  late TextEditingController _descriptionController;
  bool _descriptionChanged = false;

  // 获取来源
  late AcquisitionType _acquisitionType;
  late TextEditingController _acquisitionCostController;
  late TextEditingController _acquisitionCustomController;
  bool _acquisitionChanged = false;

  // 符卡/技能编辑追踪
  final Map<int, SpellCardEditData> _spellCardEdits = {};
  final List<SpellCardCreateData> _spellCardCreates = [];
  final Set<int> _spellCardDeletes = {};

  final Map<int, ZombieSkillEditData> _zombieSkillEdits = {};
  final List<ZombieSkillCreateData> _zombieSkillCreates = [];
  final Set<int> _zombieSkillDeletes = {};

  // 预览图编辑追踪
  int? _thumbnailFileId;
  int? _previewFrontId;
  int? _previewLeftId;
  int? _previewRightId;
  int? _previewBackId;
  int? _previewHandId;
  int? _previewLegId;
  bool _previewImagesChanged = false;
  final GlobalKey<PreviewImagesUploadWidgetState> _previewImagesKey =
      GlobalKey();

  // 内联编辑状态
  int? _editingSpellCardId;
  TextEditingController? _tempDescriptionController;
  TextEditingController? _tempCooldownController;
  TextEditingController? _tempDamageController;
  TextEditingController? _tempCostController;
  SpellCardTier? _tempTier;

  // 僵尸技能内联编辑状态
  int? _editingZombieSkillId;
  TextEditingController? _zombieTempDescriptionController;
  TextEditingController? _zombieTempCooldownController;
  TextEditingController? _zombieTempDamageController;
  TextEditingController? _zombieTempRangeController;
  TextEditingController? _zombieTempSpecialController;

  @override
  void initState() {
    super.initState();

    // 解析待审核申请的数据（如果有）
    final parsedData = widget.pendingRequestDetail?.parsedEditData;

    // 编辑理由
    _editReasonController = TextEditingController(
      text: widget.pendingRequestDetail?.editReason ?? '',
    );

    // 角色介绍：优先使用待审核申请中的数据，其次使用子模型介绍，兜底使用角色介绍
    final pendingDescription = parsedData?.description;
    final currentDescription =
        (widget.subModel.description?.isNotEmpty ?? false)
        ? widget.subModel.description!
        : widget.character.description;
    if (pendingDescription != null) {
      _descriptionController = TextEditingController(text: pendingDescription);
      _descriptionChanged = true; // 标记为已修改
    } else {
      _descriptionController = TextEditingController(text: currentDescription);
    }

    // 获取来源：优先使用待审核申请中的数据
    final pendingAcquisition = parsedData?.acquisition;
    final currentAcquisition =
        widget.subModel.acquisition ?? widget.character.acquisition;
    if (pendingAcquisition != null) {
      _acquisitionType = pendingAcquisition.type;
      _acquisitionCostController = TextEditingController(
        text: pendingAcquisition.cost?.toString() ?? '',
      );
      _acquisitionCustomController = TextEditingController(
        text: pendingAcquisition.customSource ?? '',
      );
      _acquisitionChanged = true; // 标记为已修改
    } else {
      _acquisitionType = currentAcquisition?.type ?? AcquisitionType.unknown;
      _acquisitionCostController = TextEditingController(
        text: currentAcquisition?.cost?.toString() ?? '',
      );
      _acquisitionCustomController = TextEditingController(
        text: currentAcquisition?.customSource ?? '',
      );
    }

    // 预填充预览图编辑数据
    final pendingPreviewImages = parsedData?.previewImages;
    if (pendingPreviewImages != null && pendingPreviewImages.hasAnyChange) {
      _thumbnailFileId = pendingPreviewImages.thumbnailFileId;
      _previewFrontId = pendingPreviewImages.previewFrontId;
      _previewLeftId = pendingPreviewImages.previewLeftId;
      _previewRightId = pendingPreviewImages.previewRightId;
      _previewBackId = pendingPreviewImages.previewBackId;
      _previewHandId = pendingPreviewImages.previewHandId;
      _previewLegId = pendingPreviewImages.previewLegId;
      _previewImagesChanged = true; // 标记为已修改
    }

    // 预填充符卡编辑数据
    _initSpellCardEditsFromPendingRequest(parsedData?.spellCards);

    // 预填充僵尸技能编辑数据
    _initZombieSkillEditsFromPendingRequest(parsedData?.zombieSkills);

    // 根据角色类型决定 Tab 数量
    // 所有角色: 基本信息、预览图、获取来源/来源说明、符卡系统/技能系统
    // 东方角色: 基本信息、预览图、获取来源、符卡系统 = 4个
    // 僵尸角色: 基本信息、预览图、来源说明、技能系统 = 4个
    // 普通角色: 基本信息、预览图、获取来源 = 3个
    final isTouhou = widget.character.category == CharacterCategory.touhou;
    final isZombie = widget.character.category == CharacterCategory.zombie;
    final tabCount = (isTouhou || isZombie) ? 4 : 3;

    _tabController = TabController(length: tabCount, vsync: this);
  }

  /// 从待审核申请中初始化符卡编辑数据
  void _initSpellCardEditsFromPendingRequest(
    SpellCardsEditData? spellCardsData,
  ) {
    if (spellCardsData == null) return;

    // 预填充符卡更新
    if (spellCardsData.updates != null) {
      for (final update in spellCardsData.updates!) {
        _spellCardEdits[update.id] = SpellCardEditData(
          description: update.description,
          damage: update.damage,
          cooldown: update.cooldown,
          cost: update.cost,
        );
      }
    }

    // 预填充符卡新增
    if (spellCardsData.creates != null) {
      for (final create in spellCardsData.creates!) {
        _spellCardCreates.add(
          SpellCardCreateData(
            name: create.name,
            type: create.type,
            description: create.description,
            damage: create.damage,
            cooldown: create.cooldown,
            cost: create.cost,
          ),
        );
      }
    }

    // 预填充符卡删除
    if (spellCardsData.deletes != null) {
      _spellCardDeletes.addAll(spellCardsData.deletes!);
    }
  }

  /// 从待审核申请中初始化僵尸技能编辑数据
  void _initZombieSkillEditsFromPendingRequest(
    ZombieSkillsEditData? zombieSkillsData,
  ) {
    if (zombieSkillsData == null) return;

    // 预填充技能更新
    if (zombieSkillsData.updates != null) {
      for (final update in zombieSkillsData.updates!) {
        _zombieSkillEdits[update.id] = ZombieSkillEditData(
          description: update.description,
          damage: update.damage,
          cooldown: update.cooldown,
          range: update.range,
          special: update.special,
        );
      }
    }

    // 预填充技能新增
    if (zombieSkillsData.creates != null) {
      for (final create in zombieSkillsData.creates!) {
        _zombieSkillCreates.add(
          ZombieSkillCreateData(
            name: create.name,
            type: create.type,
            description: create.description,
            damage: create.damage,
            cooldown: create.cooldown,
            range: create.range,
            special: create.special,
          ),
        );
      }
    }

    // 预填充技能删除
    if (zombieSkillsData.deletes != null) {
      _zombieSkillDeletes.addAll(zombieSkillsData.deletes!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editReasonController.dispose();
    _descriptionController.dispose();
    _acquisitionCostController.dispose();
    _acquisitionCustomController.dispose();
    // 释放内联编辑的临时控制器
    _tempDescriptionController?.dispose();
    _tempCooldownController?.dispose();
    _tempDamageController?.dispose();
    _tempCostController?.dispose();
    // 释放僵尸技能内联编辑的临时控制器
    _zombieTempDescriptionController?.dispose();
    _zombieTempCooldownController?.dispose();
    _zombieTempDamageController?.dispose();
    _zombieTempRangeController?.dispose();
    _zombieTempSpecialController?.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _descriptionChanged ||
        _acquisitionChanged || // 僵尸角色也支持来源编辑
        _previewImagesChanged || // 预览图编辑
        _spellCardEdits.isNotEmpty ||
        _spellCardCreates.isNotEmpty ||
        _spellCardDeletes.isNotEmpty ||
        _zombieSkillEdits.isNotEmpty ||
        _zombieSkillCreates.isNotEmpty ||
        _zombieSkillDeletes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isTouhou = widget.character.category == CharacterCategory.touhou;
    final isZombie = widget.character.category == CharacterCategory.zombie;
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: washiColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scrollBrown, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(isTouhou, isZombie),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildPreviewImagesTab(),
                  // 僵尸角色使用专用的来源说明 Tab，其他角色使用获取来源 Tab
                  if (isZombie)
                    _buildZombieOriginTab()
                  else
                    _buildAcquisitionTab(),
                  if (isTouhou) _buildSpellCardsTab(),
                  if (isZombie) _buildZombieSkillsTab(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = widget.subModel.isDefault
        ? widget.character.name
        : widget.subModel.name;
    final isEditMode = widget.isEditMode;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEditMode
            ? Colors.orange.withValues(alpha: 0.1)
            : scrollBrown.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final vermillion = CharacterGalleryTheme.getVermillion(context);
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEditMode
                      ? Colors.orange.withValues(alpha: 0.15)
                      : vermillion.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditMode ? Icons.edit_document : Icons.edit_note_outlined,
                  color: isEditMode ? Colors.orange : vermillion,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEditMode ? '修改编辑申请' : '编辑角色信息',
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isEditMode) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '待审核',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  displayName,
                  style: TextStyle(
                    color: inkColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmClose(),
            icon: Icon(Icons.close, color: scrollBrown),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isTouhou, bool isZombie) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scrollBrown.withValues(alpha: 0.3)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: vermillion,
        unselectedLabelColor: inkColor.withValues(alpha: 0.6),
        indicatorColor: vermillion,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          const Tab(text: '基本信息'),
          const Tab(text: '预览图'),
          // 僵尸角色显示"来源说明"，其他角色显示"获取来源"
          Tab(text: isZombie ? '来源说明' : '获取来源'),
          if (isTouhou) const Tab(text: '符卡系统'),
          if (isZombie) const Tab(text: '技能系统'),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 修改模式提示
          if (widget.isEditMode) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '您正在修改待审核的编辑申请，修改后将替换原申请内容',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle('角色介绍', Icons.description_outlined),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            onChanged: (value) {
              setState(() {
                // 与当前子模型介绍比较，兜底与角色介绍比较
                final currentDescription =
                    (widget.subModel.description?.isNotEmpty ?? false)
                    ? widget.subModel.description!
                    : widget.character.description;
                _descriptionChanged = value != currentDescription;
              });
            },
            style: TextStyle(color: inkColor, fontSize: 15, height: 1.7),
            decoration: _buildInputDecoration('描述角色的背景、特点等...'),
          ),
          if (_descriptionChanged) ...[
            const SizedBox(height: 8),
            _buildChangeIndicator('介绍已修改'),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewImagesTab() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    // 获取当前预览图URL
    final preview = widget.subModel.preview ?? widget.character.preview;
    final thumbnailUrl = widget.subModel.thumbnailUrl;

    // 获取待审核申请中的预览图 fileId（用于预填充）
    final pendingPreviewImages = widget.pendingRequestDetail?.parsedEditData?.previewImages;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 说明文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scrollBrown.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scrollBrown.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: scrollBrown, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '上传角色的预览图。缩略图用于列表展示，四方向预览图用于详情页展示。所有图片均为可选。',
                    style: TextStyle(
                      color: inkColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 预览图上传组件
          PreviewImagesUploadWidget(
            key: _previewImagesKey,
            thumbnailUrl: thumbnailUrl,
            frontUrl: preview?.front,
            leftUrl: preview?.left,
            rightUrl: preview?.right,
            backUrl: preview?.back,
            handUrl: preview?.hand,
            legUrl: preview?.leg,
            // 传入待审核申请中的 fileId（用于预填充显示）
            thumbnailFileId: pendingPreviewImages?.thumbnailFileId,
            frontFileId: pendingPreviewImages?.previewFrontId,
            leftFileId: pendingPreviewImages?.previewLeftId,
            rightFileId: pendingPreviewImages?.previewRightId,
            backFileId: pendingPreviewImages?.previewBackId,
            handFileId: pendingPreviewImages?.previewHandId,
            legFileId: pendingPreviewImages?.previewLegId,
            onChanged: (fileIds) {
              setState(() {
                _thumbnailFileId = fileIds['thumbnailFileId'];
                _previewFrontId = fileIds['previewFrontId'];
                _previewLeftId = fileIds['previewLeftId'];
                _previewRightId = fileIds['previewRightId'];
                _previewBackId = fileIds['previewBackId'];
                _previewHandId = fileIds['previewHandId'];
                _previewLegId = fileIds['previewLegId'];
                _previewImagesChanged =
                    _thumbnailFileId != null ||
                    _previewFrontId != null ||
                    _previewLeftId != null ||
                    _previewRightId != null ||
                    _previewBackId != null ||
                    _previewHandId != null ||
                    _previewLegId != null;
              });
            },
          ),

          if (_previewImagesChanged) ...[
            const SizedBox(height: 12),
            _buildChangeIndicator('预览图已修改'),
          ],
        ],
      ),
    );
  }

  Widget _buildAcquisitionTab() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 判断是否已维护：如果原始数据不为null且不是unknown，则认为已维护
    final originalAcquisition =
        widget.subModel.acquisition ?? widget.character.acquisition;
    final isMaintained =
        originalAcquisition != null &&
        originalAcquisition.type != AcquisitionType.unknown;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('获取类型', Icons.shopping_bag_outlined),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAcquisitionTypeChip('金', AcquisitionType.gold, gold),
              _buildAcquisitionTypeChip(
                '点',
                AcquisitionType.points,
                vermillion,
              ),
              _buildAcquisitionTypeChip(
                '自定义',
                AcquisitionType.custom,
                const Color(0xFF4A7C59),
              ),
              // 只有未维护时才显示"未知"选项
              if (!isMaintained)
                _buildAcquisitionTypeChip(
                  '未知',
                  AcquisitionType.unknown,
                  scrollBrown,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_acquisitionType == AcquisitionType.gold ||
              _acquisitionType == AcquisitionType.points) ...[
            _buildSectionTitle(
              _acquisitionType == AcquisitionType.gold ? '金数量' : '点数量',
              Icons.monetization_on_outlined,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _acquisitionCostController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _checkAcquisitionChanged(),
                style: TextStyle(color: inkColor, fontSize: 14),
                decoration: _buildInputDecoration('例：2000'),
              ),
            ),
          ],
          if (_acquisitionType == AcquisitionType.custom) ...[
            _buildSectionTitle('自定义来源', Icons.card_giftcard_outlined),
            const SizedBox(height: 8),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _acquisitionCustomController,
                onChanged: (_) => _checkAcquisitionChanged(),
                style: TextStyle(color: inkColor, fontSize: 14),
                decoration: _buildInputDecoration('例：捐助者、OP、活动奖励'),
              ),
            ),
          ],
          if (_acquisitionChanged) ...[
            const SizedBox(height: 12),
            _buildChangeIndicator('获取来源已修改'),
          ],
        ],
      ),
    );
  }

  /// 僵尸来源预设选项（直接存储中文值）
  static const List<String> _zombieOriginPresets = ['随机母体', '感染变化'];

  /// 判断当前来源是否为预设值
  bool get _isZombieOriginPreset =>
      _zombieOriginPresets.contains(_acquisitionCustomController.text);

  /// 获取当前选中的僵尸来源（预设值或 null 表示自定义）
  String? get _currentZombieOriginPreset {
    if (_acquisitionType != AcquisitionType.custom) {
      return null; // 默认选自定义
    }
    final source = _acquisitionCustomController.text;
    if (_zombieOriginPresets.contains(source)) {
      return source;
    }
    return null; // 自定义
  }

  /// 僵尸来源说明 Tab（专用于 zombie 类型角色）
  Widget _buildZombieOriginTab() {
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    // 判断是否已维护：如果原始数据不为null且不是unknown，则认为已维护
    final originalAcquisition =
        widget.subModel.acquisition ?? widget.character.acquisition;
    final isMaintained =
        originalAcquisition != null &&
        originalAcquisition.type != AcquisitionType.unknown;

    // 预设选项的颜色
    const presetColors = {
      '随机母体': Color(0xFFB44D4D), // 红色 - 母体
      '感染变化': Color(0xFF6B8E5A), // 绿色 - 感染
    };
    const customColor = Color(0xFF4A7C59); // 深绿色 - 自定义

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('来源类型', Icons.category_outlined),
          const SizedBox(height: 12),

          // 预设选项
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._zombieOriginPresets.map(
                (preset) => _buildZombieOriginChip(
                  preset,
                  preset,
                  presetColors[preset] ?? scrollBrown,
                  isMaintained: isMaintained,
                ),
              ),
              // 自定义选项
              _buildZombieOriginChip('自定义', null, customColor, isMaintained: isMaintained),
              // 只有未维护时才显示"未知"选项
              if (!isMaintained)
                _buildZombieOriginChip('未知', 'unknown', scrollBrown, isMaintained: isMaintained),
            ],
          ),

          // 自定义输入框（仅在选择"自定义"时显示，且不是未知状态）
          if (_acquisitionType == AcquisitionType.custom && 
              _currentZombieOriginPreset == null && 
              !_isZombieOriginPreset) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('自定义来源', Icons.edit_outlined),
            const SizedBox(height: 8),
            SizedBox(
              width: 400,
              child: TextField(
                controller: _acquisitionCustomController,
                onChanged: (_) => _checkAcquisitionChanged(),
                style: TextStyle(color: inkColor, fontSize: 14),
                decoration: _buildInputDecoration('例：管理员设置、活动奖励...'),
              ),
            ),
          ],

          if (_acquisitionChanged) ...[
            const SizedBox(height: 12),
            _buildChangeIndicator('来源已修改'),
          ],
        ],
      ),
    );
  }

  /// 构建僵尸来源选择芯片
  /// [label] 显示的文本
  /// [value] 存储的值，null 表示自定义选项
  /// 构建僵尸来源选择芯片
  /// [label] 显示的文本
  /// [value] 存储的值，null 表示自定义选项，'unknown' 表示未知选项
  /// [isMaintained] 是否已维护
  Widget _buildZombieOriginChip(String label, String? value, Color color, {required bool isMaintained}) {
    // 判断是否选中
    bool isSelected;
    if (value == 'unknown') {
      // "未知"选项：当 _acquisitionType 是 unknown 时选中
      isSelected = _acquisitionType == AcquisitionType.unknown;
    } else if (value == null) {
      // "自定义"选项：当 _acquisitionType 是 custom 且不是预设值时选中
      isSelected = _acquisitionType == AcquisitionType.custom && 
                   _currentZombieOriginPreset == null && 
                   !_isZombieOriginPreset;
    } else {
      // 预设选项：当 _acquisitionType 是 custom 且 customSource 等于该值时选中
      isSelected = _acquisitionType == AcquisitionType.custom && 
                   _acquisitionCustomController.text == value;
    }
    
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == 'unknown') {
            // 选择"未知"时，设置为 unknown 类型
            _acquisitionType = AcquisitionType.unknown;
            _acquisitionCustomController.text = '';
          } else {
            _acquisitionType = AcquisitionType.custom;
            if (value == null) {
              // 选择自定义时，如果当前是预设值则清空
              if (_isZombieOriginPreset) {
                _acquisitionCustomController.text = '';
              }
            } else {
              // 选择预设值时，直接设置为该值
              _acquisitionCustomController.text = value;
            }
          }
          _checkAcquisitionChanged();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : inputBg,
          border: Border.all(
            color: isSelected ? color : scrollBrown.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : inkColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpellCardsTab() {
    // 过滤符卡：
    // 1. 排除已删除的符卡
    // 2. 如果不是默认角色，排除通用符卡（subModelId == null）
    final spellCards = widget.spellCards
        .where((card) => !_spellCardDeletes.contains(card.id))
        .where((card) {
          // 如果是默认角色，显示所有符卡
          if (widget.subModel.isDefault) return true;
          // 如果不是默认角色，只显示该子模型的符卡（排除通用符卡）
          return card.subModelId == widget.subModel.id;
        })
        .toList();

    // 按类型分组：被动、大符卡、小符卡
    final passive = spellCards
        .where((c) => c.type == SpellCardType.passive)
        .toList();
    final ultimate = spellCards
        .where((c) => c.type == SpellCardType.ultimate)
        .toList();
    final normal = spellCards
        .where((c) => c.type == SpellCardType.normal)
        .toList();

    // 新增符卡也按类型分组
    final newPassive = _spellCardCreates
        .asMap()
        .entries
        .where((e) => e.value.type == 'passive')
        .toList();
    final newUltimate = _spellCardCreates
        .asMap()
        .entries
        .where((e) => e.value.type == 'ultimate')
        .toList();
    final newNormal = _spellCardCreates
        .asMap()
        .entries
        .where((e) => e.value.type == 'normal')
        .toList();

    final gold = CharacterGalleryTheme.getGold(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionTitle('符卡列表', Icons.auto_awesome),
              const Spacer(),
              _buildAddButton('新增符卡', () => _showAddSpellCardDialog()),
            ],
          ),
          const SizedBox(height: 16),
          if (spellCards.isEmpty && _spellCardCreates.isEmpty)
            _buildEmptyHint('暂无符卡数据')
          else ...[
            // 被动技能
            if (passive.isNotEmpty || newPassive.isNotEmpty) ...[
              _buildSpellCardGroupHeader('被动技能', const Color(0xFF4A7C59)),
              const SizedBox(height: 8),
              ...passive.map((card) => _buildSpellCardItem(card)),
              ...newPassive.map(
                (entry) => _buildNewSpellCardItem(entry.key, entry.value),
              ),
              const SizedBox(height: 16),
            ],
            // 大符卡
            if (ultimate.isNotEmpty || newUltimate.isNotEmpty) ...[
              _buildSpellCardGroupHeader('大符卡', gold),
              const SizedBox(height: 8),
              ...ultimate.map((card) => _buildSpellCardItem(card)),
              ...newUltimate.map(
                (entry) => _buildNewSpellCardItem(entry.key, entry.value),
              ),
              const SizedBox(height: 16),
            ],
            // 小符卡
            if (normal.isNotEmpty || newNormal.isNotEmpty) ...[
              _buildSpellCardGroupHeader('小符卡', vermillion),
              const SizedBox(height: 8),
              ...normal.map((card) => _buildSpellCardItem(card)),
              ...newNormal.map(
                (entry) => _buildNewSpellCardItem(entry.key, entry.value),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 符卡分组标题
  Widget _buildSpellCardGroupHeader(String title, Color color) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: scrollBrown,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  Widget _buildZombieSkillsTab() {
    final skills =
        widget.character.zombieSkills
            ?.where((skill) => !_zombieSkillDeletes.contains(skill.id))
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionTitle('技能列表', Icons.flash_on),
              const Spacer(),
              _buildAddButton('新增技能', () => _showAddZombieSkillDialog()),
            ],
          ),
          const SizedBox(height: 16),
          if (skills.isEmpty && _zombieSkillCreates.isEmpty)
            _buildEmptyHint('暂无技能数据')
          else ...[
            // 现有技能
            ...skills.map((skill) => _buildZombieSkillItem(skill)),
            // 新增的技能
            ..._zombieSkillCreates.asMap().entries.map(
              (entry) => _buildNewZombieSkillItem(entry.key, entry.value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpellCardItem(SpellCard card) {
    final editData = _spellCardEdits[card.id];
    final isEdited = editData != null;
    final isEditing = _editingSpellCardId == card.id;
    final type = card.type;
    // 获取当前评级（优先使用编辑后的值）
    final currentTier = isEditing ? _tempTier : (editData?.tier ?? card.tier);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 类型对应的颜色、符号和背景图
    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = switch (type) {
      SpellCardType.passive => (
        const Color(0xFF4A7C59),
        const Color(0xFF4A7C59).withValues(alpha: 0.08),
        '✦',
        'assets/images/character_gallery/spell_card_bg_passive.png',
      ),
      SpellCardType.ultimate => (
        gold,
        gold.withValues(alpha: 0.08),
        '◈',
        'assets/images/character_gallery/spell_card_bg_ultimate.png',
      ),
      SpellCardType.normal => (
        vermillion,
        vermillion.withValues(alpha: 0.06),
        '✧',
        'assets/images/character_gallery/spell_card_bg_normal.png',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: isEditing ? gold : (isEdited ? vermillion : borderColor),
          width: isEditing ? 2.5 : (isEdited ? 2 : 1.5),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // 背景图层
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.2 : 0.5),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：符号 + 名称 + 评级 + 状态 + 操作按钮
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 14,
                          shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          card.name,
                          style: TextStyle(
                            color: inkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      // 评级标签（编辑模式下可点击修改）
                      if (isEditing) ...[
                        PopupMenuButton<SpellCardTier?>(
                          initialValue: currentTier,
                          onSelected: (tier) =>
                              setState(() => _tempTier = tier),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: overlayColor,
                              border: Border.all(
                                color:
                                    currentTier != null &&
                                        currentTier != SpellCardTier.unranked
                                    ? _getTierColor(currentTier)
                                    : inkColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentTier?.label ?? '选择评级',
                                  style: TextStyle(
                                    color:
                                        currentTier != null &&
                                            currentTier !=
                                                SpellCardTier.unranked
                                        ? _getTierColor(currentTier)
                                        : inkColor.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color:
                                      currentTier != null &&
                                          currentTier != SpellCardTier.unranked
                                      ? _getTierColor(currentTier)
                                      : inkColor.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: null,
                              child: Text(
                                '未选择',
                                style: TextStyle(color: inkColor, fontSize: 13),
                              ),
                            ),
                            ...SpellCardTier.values.map(
                              (tier) => PopupMenuItem(
                                value: tier,
                                child: Text(
                                  tier.label,
                                  style: TextStyle(
                                    color: _getTierColor(tier),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ] else if (currentTier != null &&
                          currentTier != SpellCardTier.unranked) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            border: Border.all(
                              color: _getTierColor(currentTier),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentTier.label,
                            style: TextStyle(
                              color: _getTierColor(currentTier),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 已修改/编辑中标签
                      if (isEditing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '编辑中',
                            style: TextStyle(
                              color: gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (isEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '已修改',
                            style: TextStyle(
                              color: vermillion,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // 操作按钮
                      if (isEditing) ...[
                        _buildIconButton(
                          Icons.check,
                          () => _saveInlineSpellCardEdit(card),
                          color: Colors.green,
                        ),
                        _buildIconButton(
                          Icons.close,
                          _cancelInlineSpellCardEdit,
                          color: Colors.grey,
                        ),
                      ] else ...[
                        _buildIconButton(
                          Icons.edit_outlined,
                          () => _editSpellCard(card),
                        ),
                        _buildIconButton(
                          Icons.delete_outline,
                          () => _deleteSpellCard(card.id),
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),

                  // 分隔线
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            borderColor.withValues(alpha: 0),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.2, 0.8, 1],
                        ),
                      ),
                    ),
                  ),

                  // 描述区域：编辑时显示带边框的输入框
                  isEditing
                      ? Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 10,
                                top: 8,
                                bottom: 24,
                              ),
                              decoration: BoxDecoration(
                                color: overlayColor.withValues(alpha: 0.3),
                                border: Border.all(
                                  color: borderColor.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: TextField(
                                controller: _tempDescriptionController!,
                                maxLines: null,
                                minLines: 2,
                                maxLength: 200,
                                style: TextStyle(
                                  color: inkColor.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  hintText: '描述符卡的效果...',
                                  hintStyle: TextStyle(
                                    color: inkColor.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                  counterText: '',
                                ),
                              ),
                            ),
                            // 字数统计浮于右下角
                            Positioned(
                              right: 8,
                              bottom: 6,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _tempDescriptionController!,
                                builder: (context, value, child) {
                                  final count = value.text.length;
                                  final isOverLimit = count > 200;
                                  return Text(
                                    '$count/200',
                                    style: TextStyle(
                                      color: isOverLimit
                                          ? Colors.red
                                          : inkColor.withValues(alpha: 0.5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Text(
                          editData?.description ?? card.description,
                          style: TextStyle(
                            color: inkColor.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.4,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 2),
                            ],
                          ),
                        ),

                  // 属性行 - 编辑模式下始终显示，非编辑模式下有数据才显示
                  if (isEditing ||
                      ((editData?.cooldown ?? card.cooldown) != null ||
                          (editData?.damage ?? card.damage) != null ||
                          (editData?.cost ?? card.cost) != null)) ...[
                    const SizedBox(height: 10),
                    if (isEditing)
                      _buildEditableStatsRow(
                        card,
                        borderColor,
                        inkColor,
                        overlayColor,
                      )
                    else
                      _buildSpellCardStatsRow(
                        cooldown: editData?.cooldown ?? card.cooldown,
                        damage: editData?.damage ?? card.damage,
                        cost: editData?.cost ?? card.cost,
                        type: card.type.name,
                        accentColor: borderColor,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 可编辑的属性行
  Widget _buildEditableStatsRow(
    SpellCard card,
    Color accentColor,
    Color inkColor,
    Color overlayColor,
  ) {
    return Row(
      children: [
        // 冷却时间
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.timer_outlined,
            iconColor: CharacterGalleryTheme.getCooldownColor(context),
            controller: _tempCooldownController!,
            hint: '60',
            suffix: '秒',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.number,
          ),
        ),
        const SizedBox(width: 8),
        // 伤害
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.flash_on,
            iconColor: CharacterGalleryTheme.getDamageColor(context),
            controller: _tempDamageController!,
            hint: '150-300',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.damage,
          ),
        ),
        const SizedBox(width: 8),
        // 消耗
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.local_fire_department,
            iconColor: card.type == SpellCardType.ultimate
                ? CharacterGalleryTheme.getGold(context)
                : CharacterGalleryTheme.getPCostColor(context),
            controller: _tempCostController!,
            hint: card.type == SpellCardType.ultimate ? '100' : '50',
            suffix: card.type == SpellCardType.ultimate ? 'B' : 'P',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.number,
          ),
        ),
      ],
    );
  }

  // 等宽内联属性输入框
  Widget _buildInlineStatFieldExpanded({
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String hint,
    String? suffix,
    required Color inkColor,
    required Color overlayColor,
    StatFieldType fieldType = StatFieldType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: overlayColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 22,
              child: TextField(
                controller: controller,
                keyboardType: fieldType == StatFieldType.number
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: _getInputFormatters(fieldType),
                style: TextStyle(
                  color: inkColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(1),
                    borderSide: BorderSide(
                      color: iconColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: inkColor.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          if (suffix != null)
            Text(
              suffix,
              style: TextStyle(
                color: inkColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  List<TextInputFormatter>? _getInputFormatters(StatFieldType fieldType) {
    return switch (fieldType) {
      StatFieldType.number => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        _SingleDecimalPointFormatter(),
      ],
      StatFieldType.damage => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\-~\/.\s]')),
      ],
      StatFieldType.text => null,
    };
  }

  Widget _buildNewSpellCardItem(int index, SpellCardCreateData data) {
    // 类型对应的颜色、符号和背景图
    final type = data.type;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    final (
      Color borderColor,
      Color bgColor,
      String symbol,
      String bgAsset,
    ) = switch (type) {
      'passive' => (
        const Color(0xFF4A7C59),
        const Color(0xFF4A7C59).withValues(alpha: 0.08),
        '✦',
        'assets/images/character_gallery/spell_card_bg_passive.png',
      ),
      'ultimate' => (
        gold,
        gold.withValues(alpha: 0.08),
        '◈',
        'assets/images/character_gallery/spell_card_bg_ultimate.png',
      ),
      _ => (
        vermillion,
        vermillion.withValues(alpha: 0.06),
        '✧',
        'assets/images/character_gallery/spell_card_bg_normal.png',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: const Color(0xFF4A7C59), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // 背景图层
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.2 : 0.5),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 14,
                          shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.name,
                          style: TextStyle(
                            color: inkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      // 评级标签
                      if (data.tier != null &&
                          data.tier != SpellCardTier.unranked) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            border: Border.all(
                              color: _getTierColor(data.tier!),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            data.tier!.label,
                            style: TextStyle(
                              color: _getTierColor(data.tier!),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 新增标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: overlayColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '新增',
                          style: TextStyle(
                            color: Color(0xFF4A7C59),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildIconButton(
                        Icons.edit_outlined,
                        () => _editNewSpellCard(index, data),
                      ),
                      _buildIconButton(
                        Icons.delete_outline,
                        () => setState(() => _spellCardCreates.removeAt(index)),
                        color: Colors.red,
                      ),
                    ],
                  ),

                  // 分隔线
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            borderColor.withValues(alpha: 0),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.2, 0.8, 1],
                        ),
                      ),
                    ),
                  ),

                  // 描述
                  Text(
                    data.description ?? '暂无描述',
                    style: TextStyle(
                      color: inkColor.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                      shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                    ),
                  ),

                  // 属性行
                  if (data.cooldown != null ||
                      data.damage != null ||
                      data.cost != null) ...[
                    const SizedBox(height: 10),
                    _buildSpellCardStatsRow(
                      cooldown: data.cooldown,
                      damage: data.damage,
                      cost: data.cost,
                      type: data.type,
                      accentColor: borderColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZombieSkillItem(ZombieSkill skill) {
    final editData = _zombieSkillEdits[skill.id];
    final isEdited = editData != null;
    final isEditing = _editingZombieSkillId == skill.id;
    final isActive = skill.type == ZombieSkillType.active;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final gold = CharacterGalleryTheme.getGold(context);

    // 类型对应的颜色、符号和背景图
    final (Color borderColor, String symbol, String bgAsset) = isActive
        ? (
            vermillion,
            '◈',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          )
        : (
            const Color(0xFF4A7C59),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.08),
        border: Border.all(
          color: isEditing ? gold : (isEdited ? vermillion : borderColor),
          width: isEditing ? 2.5 : (isEdited ? 2 : 1.5),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // 背景图层
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.2 : 0.5),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行：符号 + 名称 + 状态 + 操作按钮
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 14,
                          shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          skill.name,
                          style: TextStyle(
                            color: inkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: overlayColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? '主动' : '被动',
                          style: TextStyle(
                            color: borderColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 已修改/编辑中标签
                      if (isEditing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '编辑中',
                            style: TextStyle(
                              color: gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (isEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: overlayColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '已修改',
                            style: TextStyle(
                              color: vermillion,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // 操作按钮
                      if (isEditing) ...[
                        _buildIconButton(
                          Icons.check,
                          () => _saveZombieSkillInlineEdit(skill),
                          color: Colors.green,
                        ),
                        _buildIconButton(
                          Icons.close,
                          _cancelZombieSkillInlineEdit,
                          color: Colors.grey,
                        ),
                      ] else ...[
                        _buildIconButton(
                          Icons.edit_outlined,
                          () => _startZombieSkillInlineEdit(skill),
                        ),
                        _buildIconButton(
                          Icons.delete_outline,
                          () => _deleteZombieSkill(skill.id),
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),

                  // 分隔线
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            borderColor.withValues(alpha: 0),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.2, 0.8, 1],
                        ),
                      ),
                    ),
                  ),

                  // 描述区域：与符卡一致的样式
                  isEditing
                      ? Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 10,
                                top: 8,
                                bottom: 24,
                              ),
                              decoration: BoxDecoration(
                                color: overlayColor.withValues(alpha: 0.3),
                                border: Border.all(
                                  color: borderColor.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: TextField(
                                controller: _zombieTempDescriptionController!,
                                maxLines: null,
                                minLines: 2,
                                maxLength: 200,
                                style: TextStyle(
                                  color: inkColor.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(1),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  hintText: '描述技能的效果...',
                                  hintStyle: TextStyle(
                                    color: inkColor.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                  counterText: '',
                                ),
                              ),
                            ),
                            // 字数统计浮于右下角
                            Positioned(
                              right: 8,
                              bottom: 6,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable:
                                    _zombieTempDescriptionController!,
                                builder: (context, value, child) {
                                  final count = value.text.length;
                                  final isOverLimit = count > 200;
                                  return Text(
                                    '$count/200',
                                    style: TextStyle(
                                      color: isOverLimit
                                          ? Colors.red
                                          : inkColor.withValues(alpha: 0.5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Text(
                          editData?.description ?? skill.description,
                          style: TextStyle(
                            color: inkColor.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.4,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 2),
                            ],
                          ),
                        ),

                  // 属性行
                  const SizedBox(height: 10),
                  if (isEditing)
                    _buildEditableZombieSkillStatsRow(
                      skill,
                      borderColor,
                      inkColor,
                      overlayColor,
                    )
                  else if ((editData?.cooldown ?? skill.cooldown) != null ||
                      (editData?.damage ?? skill.damage) != null ||
                      (editData?.range ?? skill.range) != null ||
                      (editData?.special ?? skill.special) != null)
                    _buildZombieSkillStatsRow(
                      cooldown: editData?.cooldown ?? skill.cooldown,
                      damage: editData?.damage ?? skill.damage,
                      range: editData?.range ?? skill.range,
                      special: editData?.special ?? skill.special,
                      accentColor: borderColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 可编辑的僵尸技能属性行（与符卡一致的样式）
  Widget _buildEditableZombieSkillStatsRow(
    ZombieSkill skill,
    Color accentColor,
    Color inkColor,
    Color overlayColor,
  ) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Row(
      children: [
        // 冷却时间
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.timer_outlined,
            iconColor: CharacterGalleryTheme.getCooldownColor(context),
            controller: _zombieTempCooldownController!,
            hint: '15',
            suffix: '秒',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.number,
          ),
        ),
        const SizedBox(width: 8),
        // 伤害
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.flash_on,
            iconColor: CharacterGalleryTheme.getDamageColor(context),
            controller: _zombieTempDamageController!,
            hint: '50-80',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.damage,
          ),
        ),
        const SizedBox(width: 8),
        // 范围
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.radar,
            iconColor: scrollBrown,
            controller: _zombieTempRangeController!,
            hint: '中距离',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.text,
          ),
        ),
        const SizedBox(width: 8),
        // 特殊效果
        Expanded(
          child: _buildInlineStatFieldExpanded(
            icon: Icons.auto_awesome,
            iconColor: CharacterGalleryTheme.getSpecialColor(context),
            controller: _zombieTempSpecialController!,
            hint: '减速50%',
            inkColor: inkColor,
            overlayColor: overlayColor,
            fieldType: StatFieldType.text,
          ),
        ),
      ],
    );
  }

  Widget _buildNewZombieSkillItem(int index, ZombieSkillCreateData data) {
    final isActive = data.type == 'active';
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final vermillion = CharacterGalleryTheme.getVermillion(context);

    // 类型对应的颜色、符号和背景图
    final (Color borderColor, String symbol, String bgAsset) = isActive
        ? (
            vermillion,
            '◈',
            'assets/images/character_gallery/spell_card_bg_ultimate.png',
          )
        : (
            const Color(0xFF4A7C59),
            '✦',
            'assets/images/character_gallery/spell_card_bg_passive.png',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.08),
        border: Border.all(color: const Color(0xFF4A7C59), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // 背景图层
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.2 : 0.5),
              ),
            ),
            // 内容层
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 14,
                          shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.name,
                          style: TextStyle(
                            color: inkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: overlayColor, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: overlayColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? '主动' : '被动',
                          style: TextStyle(
                            color: borderColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 新增标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: overlayColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '新增',
                          style: TextStyle(
                            color: Color(0xFF4A7C59),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildIconButton(
                        Icons.edit_outlined,
                        () => _editNewZombieSkill(index, data),
                      ),
                      _buildIconButton(
                        Icons.delete_outline,
                        () =>
                            setState(() => _zombieSkillCreates.removeAt(index)),
                        color: Colors.red,
                      ),
                    ],
                  ),

                  // 分隔线
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            borderColor.withValues(alpha: 0),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0.5),
                            borderColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.2, 0.8, 1],
                        ),
                      ),
                    ),
                  ),

                  // 描述
                  Text(
                    data.description ?? '暂无描述',
                    style: TextStyle(
                      color: inkColor.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                      shadows: [Shadow(color: overlayColor, blurRadius: 2)],
                    ),
                  ),

                  // 属性行
                  if (data.cooldown != null ||
                      data.damage != null ||
                      data.range != null ||
                      data.special != null) ...[
                    const SizedBox(height: 10),
                    _buildZombieSkillStatsRow(
                      cooldown: data.cooldown,
                      damage: data.damage,
                      range: data.range,
                      special: data.special,
                      accentColor: borderColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scrollBrown.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: scrollBrown.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 编辑理由
          EditReasonSelector(
            controller: _editReasonController,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_hasChanges)
                Builder(
                  builder: (context) {
                    final vermillion = CharacterGalleryTheme.getVermillion(
                      context,
                    );
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: vermillion.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 14, color: vermillion),
                          const SizedBox(width: 4),
                          Text(
                            '有未保存的修改',
                            style: TextStyle(
                              color: vermillion,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Spacer(),
              TextButton(
                onPressed: () => _confirmClose(),
                child: Text('取消', style: TextStyle(color: scrollBrown)),
              ),
              const SizedBox(width: 12),
              BlocConsumer<CharacterGalleryBloc, CharacterGalleryState>(
                listenWhen: (prev, curr) =>
                    prev.submitEditState != curr.submitEditState,
                listener: (context, state) {
                  if (state.submitEditState == LoadState.success) {
                    Navigator.pop(context);
                    ToastUtils.showSuccess(
                      context,
                      widget.isEditMode ? '申请已修改' : '编辑已提交审核',
                    );
                  } else if (state.submitEditState == LoadState.failure) {
                    ToastUtils.showError(
                      context,
                      state.submitEditError ?? '提交失败',
                    );
                  }
                },
                builder: (context, state) {
                  final isLoading = state.submitEditState == LoadState.loading;
                  final isEditMode = widget.isEditMode;
                  return ElevatedButton(
                    onPressed: isLoading || !_hasChanges ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEditMode
                          ? Colors.orange
                          : CharacterGalleryTheme.getVermillion(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditMode ? '保存修改' : '提交审核'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ 辅助组件 ============

  Widget _buildSectionTitle(String title, IconData icon) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: scrollBrown),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: scrollBrown,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAcquisitionTypeChip(
    String label,
    AcquisitionType type,
    Color color,
  ) {
    final isSelected = _acquisitionType == type;
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final cardBg = CharacterGalleryTheme.getCardBackground(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _acquisitionType = type;
            _checkAcquisitionChanged();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : cardBg,
            border: Border.all(
              color: isSelected ? color : scrollBrown.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : inkColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final inputBg = CharacterGalleryTheme.getInputBackground(context);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: inkColor.withValues(alpha: 0.4),
        fontSize: 14,
      ),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scrollBrown.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: CharacterGalleryTheme.getVermillion(context),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildChangeIndicator(String text) {
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    return Row(
      children: [
        Icon(Icons.check_circle, size: 14, color: vermillion),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: vermillion,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4A7C59).withValues(alpha: 0.1),
            border: Border.all(color: const Color(0xFF4A7C59)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: Color(0xFF4A7C59)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4A7C59),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: inkColor.withValues(alpha: 0.5), fontSize: 14),
      ),
    );
  }

  Color _getTierColor(SpellCardTier tier) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    return switch (tier) {
      SpellCardTier.t0 => const Color(0xFFFF4444),
      SpellCardTier.t1 => const Color(0xFFFF8800),
      SpellCardTier.t2 => const Color(0xFFFFCC00),
      SpellCardTier.t3 => const Color(0xFF44BB44),
      SpellCardTier.t4 => const Color(0xFF4488FF),
      SpellCardTier.t5 => const Color(0xFF8888AA),
      SpellCardTier.unranked => scrollBrown,
    };
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.7 : 0.85,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 18, color: color ?? scrollBrown),
          ),
        ),
      ),
    );
  }

  /// 符卡属性行（东方风格，带阴影）
  Widget _buildSpellCardStatsRow({
    double? cooldown,
    String? damage,
    double? cost,
    required String type,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final statItems = <Widget>[];

    if (cooldown != null) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.timer_outlined,
          '冷却',
          '${cooldown % 1 == 0 ? cooldown.toInt() : cooldown}s',
          CharacterGalleryTheme.getCooldownColor(context),
          overlayColor,
        ),
      );
    }

    if (damage != null && damage.isNotEmpty) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.flash_on,
          '伤害',
          damage,
          CharacterGalleryTheme.getDamageColor(context),
          overlayColor,
        ),
      );
    }

    if (cost != null) {
      final isUltimate = type == 'ultimate';
      statItems.add(
        _buildStatItemWithShadow(
          Icons.local_fire_department,
          isUltimate ? 'B点' : 'P点',
          '${cost % 1 == 0 ? cost.toInt() : cost}',
          isUltimate
              ? CharacterGalleryTheme.getBCostColor(context)
              : CharacterGalleryTheme.getPCostColor(context),
          overlayColor,
        ),
      );
    }

    if (statItems.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int i = 0; i < statItems.length; i++) ...[
          statItems[i],
          if (i < statItems.length - 1) ...[
            const SizedBox(width: 6),
            Text(
              '│',
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.3),
                fontSize: 12,
                shadows: [Shadow(color: overlayColor, blurRadius: 2)],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ],
    );
  }

  /// 单个属性项（带阴影，用于符卡）
  Widget _buildStatItemWithShadow(
    IconData icon,
    String label,
    String value,
    Color color,
    Color shadowColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
          shadows: [Shadow(color: shadowColor, blurRadius: 2)],
        ),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: shadowColor, blurRadius: 2)],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: shadowColor, blurRadius: 2)],
          ),
        ),
      ],
    );
  }

  /// 僵尸技能属性行（东方风格，带阴影）
  Widget _buildZombieSkillStatsRow({
    double? cooldown,
    String? damage,
    String? range,
    String? special,
    required Color accentColor,
  }) {
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = CharacterGalleryTheme.getOverlayColor(
      context,
      alpha: isDark ? 0.6 : 0.8,
    );
    final statItems = <Widget>[];

    if (cooldown != null) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.timer_outlined,
          '冷却',
          '${cooldown % 1 == 0 ? cooldown.toInt() : cooldown}s',
          CharacterGalleryTheme.getCooldownColor(context),
          overlayColor,
        ),
      );
    }

    if (damage != null && damage.isNotEmpty) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.flash_on,
          '伤害',
          damage,
          CharacterGalleryTheme.getDamageColor(context),
          overlayColor,
        ),
      );
    }

    if (range != null && range.isNotEmpty) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.radar,
          '范围',
          range,
          scrollBrown,
          overlayColor,
        ),
      );
    }

    if (special != null && special.isNotEmpty) {
      statItems.add(
        _buildStatItemWithShadow(
          Icons.auto_awesome,
          '特殊',
          special,
          CharacterGalleryTheme.getSpecialColor(context),
          overlayColor,
        ),
      );
    }

    if (statItems.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 12, runSpacing: 6, children: statItems);
  }

  // ============ 辅助方法 ============

  void _checkAcquisitionChanged() {
    final original =
        widget.subModel.acquisition ?? widget.character.acquisition;
    final originalType = original?.type ?? AcquisitionType.unknown;
    final originalCost = original?.cost?.toString() ?? '';
    final originalCustom = original?.customSource ?? '';

    setState(() {
      // 如果原始类型和当前类型都是 unknown，则认为没有变化
      // 这样可以避免用户从未知切换到其他类型再切回未知时，因为中间输入的数据导致错误提交
      if (originalType == AcquisitionType.unknown &&
          _acquisitionType == AcquisitionType.unknown) {
        _acquisitionChanged = false;
      } else {
        _acquisitionChanged =
            _acquisitionType != originalType ||
            _acquisitionCostController.text != originalCost ||
            _acquisitionCustomController.text != originalCustom;
      }
    });
  }

  void _confirmClose() {
    if (_hasChanges) {
      final washiColor = CharacterGalleryTheme.getWashiColor(context);
      final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
      final inkColor = CharacterGalleryTheme.getInkColor(context);
      final gold = CharacterGalleryTheme.getGold(context);
      final vermillion = CharacterGalleryTheme.getVermillion(context);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: washiColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: scrollBrown, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: gold, size: 24),
              const SizedBox(width: 8),
              Text(
                '确认关闭',
                style: TextStyle(
                  color: inkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '您有未保存的修改，确定要关闭吗？',
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('继续编辑', style: TextStyle(color: scrollBrown)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: vermillion,
                foregroundColor: Colors.white,
              ),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _editSpellCard(SpellCard card) {
    final existingEdit = _spellCardEdits[card.id];

    setState(() {
      _editingSpellCardId = card.id;
      _tempDescriptionController = TextEditingController(
        text: existingEdit?.description ?? card.description,
      );
      _tempCooldownController = TextEditingController(
        text: (existingEdit?.cooldown ?? card.cooldown)?.toString() ?? '',
      );
      _tempDamageController = TextEditingController(
        text: existingEdit?.damage ?? card.damage ?? '',
      );
      _tempCostController = TextEditingController(
        text: (existingEdit?.cost ?? card.cost)?.toString() ?? '',
      );
      _tempTier = existingEdit?.tier ?? card.tier;
    });
  }

  void _saveInlineSpellCardEdit(SpellCard card) {
    if (_tempDescriptionController == null ||
        _tempDescriptionController!.text.isEmpty) {
      ToastUtils.showWarning(context, '请填写效果描述');
      return;
    }

    final descText = _tempDescriptionController!.text;
    final damageText = _tempDamageController?.text ?? '';
    final cooldownText = _tempCooldownController?.text ?? '';
    final costText = _tempCostController?.text ?? '';

    // 检查是否有实际修改
    final hasChanges =
        descText != card.description ||
        damageText != (card.damage ?? '') ||
        (cooldownText.isNotEmpty
            ? double.tryParse(cooldownText) != card.cooldown
            : card.cooldown != null) ||
        (costText.isNotEmpty
            ? double.tryParse(costText) != card.cost
            : card.cost != null) ||
        _tempTier != card.tier;

    setState(() {
      if (hasChanges) {
        _spellCardEdits[card.id] = SpellCardEditData(
          description: descText,
          damage: damageText.isNotEmpty ? damageText : null,
          cooldown: double.tryParse(cooldownText),
          cost: double.tryParse(costText),
          tier: _tempTier,
        );
      } else {
        // 如果没有修改，移除编辑记录
        _spellCardEdits.remove(card.id);
      }
      _editingSpellCardId = null;
    });

    _tempDescriptionController?.dispose();
    _tempDescriptionController = null;
    _tempCooldownController?.dispose();
    _tempCooldownController = null;
    _tempDamageController?.dispose();
    _tempDamageController = null;
    _tempCostController?.dispose();
    _tempCostController = null;
  }

  void _cancelInlineSpellCardEdit() {
    setState(() {
      _editingSpellCardId = null;
    });

    _tempDescriptionController?.dispose();
    _tempDescriptionController = null;
    _tempCooldownController?.dispose();
    _tempCooldownController = null;
    _tempDamageController?.dispose();
    _tempDamageController = null;
    _tempCostController?.dispose();
    _tempCostController = null;
  }

  void _editNewSpellCard(int index, SpellCardCreateData data) {
    showDialog(
      context: context,
      builder: (ctx) => NewSpellCardEditSubDialog(
        data: data,
        onSave: (updatedData) {
          setState(() {
            _spellCardCreates[index] = updatedData;
          });
        },
      ),
    );
  }

  void _deleteSpellCard(int cardId) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: washiColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scrollBrown, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              '确认删除',
              style: TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要删除这个符卡吗？此操作需要审核通过后生效。',
          style: TextStyle(
            color: inkColor.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _spellCardDeletes.add(cardId);
                _spellCardEdits.remove(cardId);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _showAddSpellCardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SpellCardCreateSubDialog(
        onSave: (createData) {
          setState(() {
            _spellCardCreates.add(createData);
          });
        },
      ),
    );
  }

  // ============ 僵尸技能内联编辑方法 ============

  /// 开始僵尸技能内联编辑
  void _startZombieSkillInlineEdit(ZombieSkill skill) {
    final existingEdit = _zombieSkillEdits[skill.id];

    // 释放之前的控制器
    _zombieTempDescriptionController?.dispose();
    _zombieTempCooldownController?.dispose();
    _zombieTempDamageController?.dispose();
    _zombieTempRangeController?.dispose();
    _zombieTempSpecialController?.dispose();

    // 创建新的控制器
    _zombieTempDescriptionController = TextEditingController(
      text: existingEdit?.description ?? skill.description,
    );
    _zombieTempCooldownController = TextEditingController(
      text: (existingEdit?.cooldown ?? skill.cooldown)?.toString() ?? '',
    );
    _zombieTempDamageController = TextEditingController(
      text: existingEdit?.damage ?? skill.damage ?? '',
    );
    _zombieTempRangeController = TextEditingController(
      text: existingEdit?.range ?? skill.range ?? '',
    );
    _zombieTempSpecialController = TextEditingController(
      text: existingEdit?.special ?? skill.special ?? '',
    );

    setState(() {
      _editingZombieSkillId = skill.id;
    });
  }

  /// 保存僵尸技能内联编辑
  void _saveZombieSkillInlineEdit(ZombieSkill skill) {
    final newDescription =
        _zombieTempDescriptionController?.text ?? skill.description;
    final newCooldown = double.tryParse(
      _zombieTempCooldownController?.text ?? '',
    );
    final newDamage = _zombieTempDamageController?.text;
    final newRange = _zombieTempRangeController?.text;
    final newSpecial = _zombieTempSpecialController?.text;

    setState(() {
      _zombieSkillEdits[skill.id] = ZombieSkillEditData(
        description: newDescription,
        cooldown: newCooldown,
        damage: newDamage?.isNotEmpty == true ? newDamage : null,
        range: newRange?.isNotEmpty == true ? newRange : null,
        special: newSpecial?.isNotEmpty == true ? newSpecial : null,
      );
      _editingZombieSkillId = null;
    });
  }

  /// 取消僵尸技能内联编辑
  void _cancelZombieSkillInlineEdit() {
    setState(() {
      _editingZombieSkillId = null;
    });
  }

  void _deleteZombieSkill(int skillId) {
    final washiColor = CharacterGalleryTheme.getWashiColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);
    final inkColor = CharacterGalleryTheme.getInkColor(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: washiColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scrollBrown, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              '确认删除',
              style: TextStyle(
                color: inkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '确定要删除这个技能吗？此操作需要审核通过后生效。',
          style: TextStyle(
            color: inkColor.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: scrollBrown)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _zombieSkillDeletes.add(skillId);
                _zombieSkillEdits.remove(skillId);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _showAddZombieSkillDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ZombieSkillCreateSubDialog(
        onSave: (createData) {
          setState(() {
            _zombieSkillCreates.add(createData);
          });
        },
      ),
    );
  }

  void _editNewZombieSkill(int index, ZombieSkillCreateData data) {
    showDialog(
      context: context,
      builder: (ctx) => NewZombieSkillEditSubDialog(
        data: data,
        onSave: (updatedData) {
          setState(() {
            _zombieSkillCreates[index] = updatedData;
          });
        },
      ),
    );
  }

  void _onSubmit() {
    if (_editReasonController.text.isEmpty) {
      ToastUtils.showWarning(context, '请选择或填写编辑理由');
      return;
    }

    if (!_hasChanges) {
      ToastUtils.showWarning(context, '没有需要提交的修改');
      return;
    }

    // 获取实际的子模型ID（虚拟子模型ID为0时使用角色的defaultSubModelId）
    final actualSubModelId = widget.subModel.id != 0
        ? widget.subModel.id
        : (widget.character.defaultSubModelId ?? 0);

    // 检查子模型ID是否有效
    if (actualSubModelId == 0) {
      ToastUtils.showError(context, '无法确定子模型，请稍后重试');
      return;
    }

    // 构建通用的编辑数据
    final description = _descriptionChanged
        ? _descriptionController.text
        : null;
    // 获取途径/来源说明：如果类型是 unknown，则传 null（表示清除），否则传具体数据
    // 注意：僵尸角色也可以提交来源说明
    final acquisition = _acquisitionChanged
        ? (_acquisitionType == AcquisitionType.unknown
              ? null
              : AcquisitionEditData(
                  type: _acquisitionType,
                  cost: int.tryParse(_acquisitionCostController.text),
                  customSource: _acquisitionCustomController.text.isNotEmpty
                      ? _acquisitionCustomController.text
                      : null,
                ))
        : null;
    final spellCardCreates = _spellCardCreates.isNotEmpty
        ? _spellCardCreates
              .map(
                (e) => SpellCardCreateItem(
                  name: e.name,
                  type: e.type,
                  tier: e.tier?.name,
                  description: e.description,
                  damage: e.damage,
                  cooldown: e.cooldown,
                  cost: e.cost,
                ),
              )
              .toList()
        : null;
    final spellCardUpdates = _spellCardEdits.isNotEmpty
        ? _spellCardEdits.entries
              .map(
                (e) => SpellCardEditItem(
                  id: e.key,
                  description: e.value.description,
                  damage: e.value.damage,
                  cooldown: e.value.cooldown,
                  cost: e.value.cost,
                  tier: e.value.tier?.name,
                ),
              )
              .toList()
        : null;
    final spellCardDeletes = _spellCardDeletes.isNotEmpty
        ? _spellCardDeletes.toList()
        : null;
    final zombieSkillCreates = _zombieSkillCreates.isNotEmpty
        ? _zombieSkillCreates
              .map(
                (e) => ZombieSkillCreateItem(
                  name: e.name,
                  type: e.type,
                  description: e.description,
                  damage: e.damage,
                  cooldown: e.cooldown,
                  range: e.range,
                  special: e.special,
                ),
              )
              .toList()
        : null;
    final zombieSkillUpdates = _zombieSkillEdits.isNotEmpty
        ? _zombieSkillEdits.entries
              .map(
                (e) => ZombieSkillEditItem(
                  id: e.key,
                  description: e.value.description,
                  damage: e.value.damage,
                  cooldown: e.value.cooldown,
                  range: e.value.range,
                  special: e.value.special,
                ),
              )
              .toList()
        : null;
    final zombieSkillDeletes = _zombieSkillDeletes.isNotEmpty
        ? _zombieSkillDeletes.toList()
        : null;

    // 构建预览图编辑数据
    final previewImages = _previewImagesChanged
        ? PreviewImagesEditData(
            thumbnailFileId: _thumbnailFileId,
            previewFrontId: _previewFrontId,
            previewLeftId: _previewLeftId,
            previewRightId: _previewRightId,
            previewBackId: _previewBackId,
            previewHandId: _previewHandId,
            previewLegId: _previewLegId,
          )
        : null;

    // 根据模式选择不同的事件
    if (widget.isEditMode) {
      // 修改模式：调用 UpdateEditRequest
      context.read<CharacterGalleryBloc>().add(
        UpdateEditRequest(
          requestId: widget.pendingRequestId!,
          editReason: _editReasonController.text,
          description: description,
          acquisition: acquisition,
          spellCardCreates: spellCardCreates,
          spellCardUpdates: spellCardUpdates,
          spellCardDeletes: spellCardDeletes,
          zombieSkillCreates: zombieSkillCreates,
          zombieSkillUpdates: zombieSkillUpdates,
          zombieSkillDeletes: zombieSkillDeletes,
          previewImages: previewImages,
        ),
      );
    } else {
      // 新建模式：调用 SubmitUnifiedEdit
      context.read<CharacterGalleryBloc>().add(
        SubmitUnifiedEdit(
          characterId: widget.character.id,
          subModelId: actualSubModelId,
          editReason: _editReasonController.text,
          description: description,
          acquisition: acquisition,
          spellCardCreates: spellCardCreates,
          spellCardUpdates: spellCardUpdates,
          spellCardDeletes: spellCardDeletes,
          zombieSkillCreates: zombieSkillCreates,
          zombieSkillUpdates: zombieSkillUpdates,
          zombieSkillDeletes: zombieSkillDeletes,
          previewImages: previewImages,
        ),
      );
    }
  }
}

/// 输入字段类型
enum StatFieldType {
  number, // 数字（冷却、消耗）
  damage, // 伤害（允许范围如 150-300）
  text,   // 文本（范围、特殊效果）
}

/// 确保只有一个小数点的格式化器
class _SingleDecimalPointFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // 如果有多个小数点，拒绝输入
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }
    return newValue;
  }
}
