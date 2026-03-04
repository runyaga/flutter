/// Steampunk mIRC-style chat client for Soliplex — The Boiler Room.
library;

// ── App ──
export 'src/app/runyaga_app.dart';
export 'src/app/runyaga_config.dart';

// ── Design ──
export 'src/design/tokens/colors.dart';
export 'src/design/tokens/spacing.dart';
export 'src/design/tokens/typography.dart';
export 'src/design/theme/steampunk_theme.dart';
export 'src/design/theme/steampunk_theme_extension.dart';

// ── Layout ──
export 'src/layout/mirc_shell.dart';
export 'src/layout/server_tree_panel.dart';
export 'src/layout/nick_list_panel.dart';
export 'src/layout/channel_tab_bar.dart';
export 'src/layout/status_bar.dart';

// ── Painters ──
export 'src/painters/steel_plate_painter.dart';
export 'src/painters/hex_bolt_painter.dart';
export 'src/painters/pressure_gauge_painter.dart';
export 'src/painters/rivet_row_painter.dart';
export 'src/painters/steam_particle_painter.dart';

// ── Animations ──
export 'src/animations/furnace_pulse.dart';
export 'src/animations/pressure_gauge_widget.dart';
export 'src/animations/rivet_pop.dart';
export 'src/animations/pipe_flow_transition.dart';

// ── Markdown ──
export 'src/markdown/markdown_renderer.dart';
export 'src/markdown/steampunk_markdown_renderer.dart';
export 'src/markdown/markdown_theme_extension.dart';
export 'src/markdown/markdown_block_extension.dart';
export 'src/markdown/code_block_builder.dart';

// ── Features ──
export 'src/features/chat/chat_panel.dart';
export 'src/features/chat/chat_message_widget.dart';
export 'src/features/chat/chat_input.dart';
export 'src/features/chat/message_list.dart';
export 'src/features/connection/connect_screen.dart';

// ── Providers ──
export 'src/providers/agent_providers.dart';
export 'src/providers/room_providers.dart';
export 'src/providers/session_providers.dart';
export 'src/providers/signal_bridge.dart';
