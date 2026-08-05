class_name RunClearScreen
extends Control

## 마지막 스테이지까지 깼을 때. 런 요약을 보여주고 다시 시작한다.

signal restart()

var run: RunState


func setup(p_run: RunState) -> void:
	run = p_run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var t := UiKit.label(self, Vector2(0, 180), Vector2(1280, 70), "RUN CLEAR", 64, UiKit.GOOD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sub := UiKit.label(self, Vector2(0, 258), Vector2(1280, 30),
		UiText.t("clear.m01", "스테이지 %d개를 전부 돌파했다.") % Stages.count(), 18, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var ups := PackedStringArray()
	for tid in run.upgrades:
		if int(run.upgrades[tid]) > 0:
			ups.append("%s +%d" % [UnitData.TABLE[tid]["name"], int(run.upgrades[tid])])
	var line := UiKit.label(self, Vector2(0, 320), Vector2(1280, 26),
		UiText.t("clear.m02", "최종 강화:  %s") % (UiText.t("loadout.m09", "없음") if ups.is_empty() else "   ".join(ups)), 15)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var deck := UiKit.label(self, Vector2(0, 352), Vector2(1280, 26),
		UiText.t("clear.m03", "최종 덱:  전술 %d장 · 특수 %d장 · 남은 정제권 %d") % [
			run.hand.size(), run.special_hand.size(), run.refine_tokens], 15, UiKit.MUTED)
	deck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var b := UiKit.button(self, Vector2(540, 440), Vector2(200, 48), UiText.t("clear.m04", "타이틀로"), 17)
	b.pressed.connect(func(): restart.emit())
