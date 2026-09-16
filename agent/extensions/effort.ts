/**
 * /effort — 打开交互式选择器调整思考强度（类似 Claude Code 的选择菜单）
 *
 * 用法:
 *   /effort            打开选择器，仅列出当前模型支持的思考强度
 *   /effort <level>    直接设置: off | minimal | low | medium | high | xhigh | max
 *   /effort +          切换到下一个可用级别
 *   /effort -          切换到上一个可用级别
 */

const LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
] as const;
type Level = (typeof LEVELS)[number];

const LEVEL_LABELS: Record<Level, string> = {
  off: "关闭思考",
  minimal: "极简",
  low: "低",
  medium: "中",
  high: "高",
  xhigh: "超高",
  max: "最大",
};

/** 计算当前模型支持的思考级别（遵循 thinkingLevelMap 三态语义） */
function supportedLevels(model: any): Level[] {
  // 非推理模型只支持 off
  if (model && model.reasoning === false) return ["off"];

  const map = model?.thinkingLevelMap;
  const supported: Level[] = [];
  for (const lv of LEVELS) {
    if (map) {
      const mapped = map[lv];
      if (mapped === null) continue; // 显式标记不支持
      if ((lv === "xhigh" || lv === "max") && mapped === undefined) continue;
      supported.push(lv);
    } else {
      // 无映射：标准级别 off~high 默认支持，xhigh/max 需显式声明
      supported.push(lv);
    }
  }
  // 兜底：至少保留 off
  return supported.length > 0 ? supported : ["off"];
}

export default function (pi: any) {
  pi.registerCommand("effort", {
    description: "调整思考强度（交互式选择，按模型能力过滤）",
    handler: async (args: string | undefined, ctx: any) => {
      const current = pi.getThinkingLevel() as Level;
      const supported = supportedLevels(ctx.model);
      const arg = (args || "").trim().toLowerCase();

      // 支持直接传参快捷设置
      if (
        arg &&
        arg !== "+" &&
        arg !== "-" &&
        arg !== "next" &&
        arg !== "prev"
      ) {
        if (!(LEVELS as readonly string[]).includes(arg)) {
          ctx.ui.notify(
            `无效级别 "${arg}"。可用: ${supported.join(", ")}`,
            "error",
          );
          return;
        }
        if (!supported.includes(arg as Level)) {
          ctx.ui.notify(
            `当前模型不支持 "${arg}"。可用: ${supported.join(", ")}`,
            "error",
          );
          return;
        }
        pi.setThinkingLevel(arg as Level);
        ctx.ui.notify(`思考强度: ${current} → ${arg}`, "info");
        return;
      }

      // +/- 循环切换
      if (arg) {
        const idx = supported.indexOf(current);
        const next =
          arg === "+" || arg === "next"
            ? supported[Math.min(idx + 1, supported.length - 1)]
            : supported[Math.max(idx - 1, 0)];
        if (next === current) {
          ctx.ui.notify(`已到达边界，当前: ${current}`, "warning");
          return;
        }
        pi.setThinkingLevel(next);
        ctx.ui.notify(`思考强度: ${current} → ${next}`, "info");
        return;
      }

      // 无参数：打开交互式选择器
      const modelName = ctx.model
        ? `${ctx.model.provider ?? ""}/${ctx.model.id ?? ""}`.replace(/^\//, "")
        : "";
      const options = supported.map((lv) => {
        const marker = lv === current ? "● " : "  ";
        const suffix = lv === current ? "  ← 当前" : "";
        return `${marker}${lv.padEnd(8)} ${LEVEL_LABELS[lv]}${suffix}`;
      });

      const choice = await ctx.ui.select(
        `选择思考强度${modelName ? ` (${modelName})` : ""}:`,
        options,
      );
      if (choice === undefined) return; // 用户取消

      const level = choice.trim().split(/\s+/)[0] as Level;
      if (level !== current) {
        pi.setThinkingLevel(level);
        ctx.ui.notify(`思考强度: ${current} → ${level}`, "info");
      }
    },
  });
}
