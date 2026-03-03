import 'package:soliplex_showcase/src/demo_step.dart';

/// A single showcase demo definition.
typedef ShowcaseDemo = ({
  String name,
  String description,
  List<ShowcaseDemoStep> steps,
});

/// Registry of all showcase demos.
///
/// Each demo is a record of (name, description, steps).
class ShowcaseDemoRegistry {
  ShowcaseDemoRegistry._();

  /// All available demos.
  static const List<ShowcaseDemo> demos = [
    _errorRecovery,
    _dataFrameChart,
    _scatterPlot,
    _multiStepAnalysis,
    _fakeStreamingGauges,
    _streamGauges,
    _pieChart,
    _radarChart,
    _heatmap,
    _drawingRecognition,
    _formValidation,
    _ticTacToe,
  ];

  // ── Demo 1: Error Recovery ──────────────────────────────────────

  static const ShowcaseDemo _errorRecovery = (
    name: 'Error Recovery',
    description:
        'Demonstrates the retry loop: code fails, gets fixed, succeeds.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Buggy code',
        narration: 'The LLM writes code with a typo — pritn instead of print.',
        code: 'pritn("hello world")',
        expectsError: true,
      ),
      ShowcaseDemoStep(
        title: 'Step 2: LLM reads the error, fixes the typo',
        narration: 'Monty reported NameError. The LLM corrects pritn → print.',
        code: 'print("hello world")',
      ),
    ],
  );

  // ── Demo 2: DataFrame → Chart ──────────────────────────────────

  static const ShowcaseDemo _dataFrameChart = (
    name: 'DataFrame → Chart',
    description:
        'Creates a DataFrame, computes stats, and renders a bar chart.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Create DataFrame',
        narration: 'Python creates a DataFrame with city population data.',
        code: '''
handle = df_create([
    {"city": "Tokyo", "population": 37.4, "continent": "Asia"},
    {"city": "Delhi", "population": 32.9, "continent": "Asia"},
    {"city": "Shanghai", "population": 28.5, "continent": "Asia"},
    {"city": "São Paulo", "population": 22.4, "continent": "S. America"},
    {"city": "Mexico City", "population": 21.8, "continent": "N. America"}
])
print(f"Created DataFrame handle={handle}")
shape = df_shape(handle)
print(f"Shape: {shape[0]} rows x {shape[1]} columns")
head = df_head(handle, 5)
for row in head:
    print(row)
''',
      ),
      ShowcaseDemoStep(
        title: 'Step 2: Render bar chart',
        narration:
            'Now we visualize the data as a bar chart in the Flutter UI.',
        code: '''
chart_create({
    "type": "bar",
    "title": "World Largest Cities by Population (millions)",
    "labels": ["Tokyo", "Delhi", "Shanghai", "São Paulo", "Mexico City"],
    "values": [37.4, 32.9, 28.5, 22.4, 21.8]
})
print("Chart rendered!")
''',
      ),
    ],
  );

  // ── Demo 3: Scatter Plot ───────────────────────────────────────

  static const ShowcaseDemo _scatterPlot = (
    name: 'Scatter Plot',
    description: 'Python computes mathematical data and charts it.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Compute data',
        narration: 'Python generates √x values and creates a scatter plot.',
        code: '''
points = []
for x in range(1, 16):
    y = (x ** 0.5) * 10
    points.append([x, round(y, 1)])
    print(f"x={x}, y={round(y, 1)}")

chart_create({
    "type": "scatter",
    "title": "Square Root Curve (√x × 10)",
    "x_label": "x",
    "y_label": "√x × 10",
    "points": points
})
print(f"Plotted {len(points)} points")
''',
      ),
    ],
  );

  // ── Demo 4: Multi-Step Analysis ────────────────────────────────

  static const ShowcaseDemo _multiStepAnalysis = (
    name: 'Multi-Step Analysis',
    description:
        'Create, filter, sort, and chart — a realistic analysis workflow.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Create sales dataset',
        narration:
            'Build a sales DataFrame with regions and quarterly revenue.',
        code: '''
h = df_create([
    {"region": "North", "quarter": "Q1", "revenue": 120},
    {"region": "South", "quarter": "Q1", "revenue": 95},
    {"region": "East", "quarter": "Q1", "revenue": 140},
    {"region": "West", "quarter": "Q1", "revenue": 88},
    {"region": "North", "quarter": "Q2", "revenue": 135},
    {"region": "South", "quarter": "Q2", "revenue": 102},
    {"region": "East", "quarter": "Q2", "revenue": 155},
    {"region": "West", "quarter": "Q2", "revenue": 91}
])
print(f"Sales data created (handle={h})")
rows = df_head(h, 8)
for r in rows:
    print(r)
''',
      ),
      ShowcaseDemoStep(
        title: 'Step 2: Filter Q2 and chart',
        narration: 'Filter to Q2 only, then chart regional revenue.',
        code: '''
h = 1
q2 = df_filter(h, "quarter", "==", "Q2")
print(f"Filtered to Q2 (handle={q2})")
q2_rows = df_head(q2, 4)
regions = []
revenues = []
for r in q2_rows:
    regions.append(r["region"])
    revenues.append(r["revenue"])
    print(r)

chart_create({
    "type": "bar",
    "title": "Q2 Revenue by Region",
    "labels": regions,
    "values": revenues
})
print("Q2 chart rendered!")
''',
      ),
      ShowcaseDemoStep(
        title: 'Step 3: Growth line chart',
        narration: 'Compute Q1→Q2 growth per region and plot as a line chart.',
        code: '''
points = []
regions = ["North", "South", "East", "West"]
q1_vals = [120, 95, 140, 88]
q2_vals = [135, 102, 155, 91]
for i in range(4):
    pct = (q2_vals[i] - q1_vals[i]) / q1_vals[i] * 100
    points.append([i + 1, pct])
    print(regions[i] + ": " + str(q1_vals[i]) + " -> " + str(q2_vals[i]) + " = +" + str(round(pct * 10) / 10) + "%")

chart_create({
    "type": "line",
    "title": "Q1 -> Q2 Revenue Growth %",
    "x_label": "Region (1=N, 2=S, 3=E, 4=W)",
    "y_label": "Growth %",
    "points": points
})
print("Growth chart rendered!")
''',
      ),
    ],
  );

  // ── Demo 5: Fake Streaming Gauges ─────────────────────────────

  static const ShowcaseDemo _fakeStreamingGauges = (
    name: 'Fake Streaming Gauges',
    description: 'A live server dashboard — all computation happens in Python '
        'with sleep-based pacing.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Live dashboard (Python-driven)',
        narration: 'Creates a bar chart as gauge display, then streams '
            '30 ticks of Ornstein-Uhlenbeck random data at ~400ms intervals. '
            'Python computes the data and calls sleep() between ticks.',
        code: '''
seed = [42]
labels = ["CPU", "MEM", "NET", "DSK", "TMP"]
mus = [55.0, 40.0, 65.0, 25.0, 50.0]
vals = [55.0, 40.0, 65.0, 25.0, 50.0]

chart_id = chart_create({
    "type": "bar", "title": "Server Dashboard (Live)",
    "labels": labels, "values": vals
})

for tick in range(30):
    for i in range(5):
        seed[0] = (seed[0] * 1103515245 + 12345) % 2147483648
        n = (seed[0] / 2147483648) * 2 - 1
        vals[i] = vals[i] + 0.15 * (mus[i] - vals[i]) + 8 * n
        if vals[i] < 0:
            vals[i] = 0.0
        if vals[i] > 100:
            vals[i] = 100.0
    r = []
    for v in vals:
        r.append(round(v * 10) / 10)
    parts = []
    for j in range(5):
        parts.append(labels[j] + ":" + str(r[j]) + "%")
    print("[" + str(tick + 1) + "] " + " ".join(parts))
    chart_update(chart_id, {
        "type": "bar", "title": "Server Dashboard (Live)",
        "labels": labels, "values": r
    })
    sleep(400)
print("Stream ended.")
''',
      ),
    ],
  );

  // ── Demo 6: Stream Gauges ────────────────────────────────────

  static const ShowcaseDemo _streamGauges = (
    name: 'Stream Gauges',
    description:
        'A live server dashboard — Dart produces O-U data via a stream, '
        'Python consumes it with stream_subscribe / stream_next.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Live dashboard (Dart-driven)',
        narration: 'Subscribes to a Dart-side "server_metrics" stream that '
            'emits 30 ticks at ~400ms. Python pulls each snapshot and '
            'updates the chart — no sleep needed.',
        code: '''
chart_id = chart_create({
    "type": "bar", "title": "Server Dashboard (Live)",
    "labels": ["CPU", "MEM", "NET", "DSK", "TMP"],
    "values": [50, 50, 50, 50, 50]
})

handle = stream_subscribe("server_metrics")
tick = 0
while True:
    snapshot = stream_next(handle)
    if snapshot is None:
        break
    tick = tick + 1
    vals = snapshot["values"]
    parts = []
    for j in range(5):
        parts.append(snapshot["labels"][j] + ":" + str(vals[j]) + "%")
    print("[" + str(tick) + "] " + " ".join(parts))
    chart_update(chart_id, snapshot)

stream_close(handle)
print("Stream ended.")
''',
      ),
    ],
  );

  // ── Demo 7: Pie Chart ─────────────────────────────────────────

  static const ShowcaseDemo _pieChart = (
    name: 'Pie Chart',
    description: 'Renders a pie chart showing browser market share.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Create pie chart',
        narration: 'Visualize browser market share as a pie chart.',
        code: '''
browsers = ["Chrome", "Safari", "Firefox", "Edge", "Other"]
share = [65.0, 18.5, 6.3, 5.2, 5.0]

i = 0
while i < len(browsers):
    print(browsers[i] + ": " + str(share[i]) + "%")
    i = i + 1

chart_create({
    "type": "pie",
    "title": "Browser Market Share 2025",
    "labels": browsers,
    "values": share,
    "center_radius": 40
})
print("Pie chart rendered!")
''',
      ),
    ],
  );

  // ── Demo 6: Radar Chart ────────────────────────────────────────

  static const ShowcaseDemo _radarChart = (
    name: 'Radar Chart',
    description: 'Displays a radar chart comparing team performance metrics.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Create radar chart',
        narration: 'Plot team metrics across 5 axes on a radar chart.',
        code: '''
axes = ["Speed", "Quality", "Teamwork", "Innovation", "Delivery"]
values = [85, 92, 78, 88, 95]

i = 0
while i < len(axes):
    print(axes[i] + ": " + str(values[i]) + "/100")
    i = i + 1

chart_create({
    "type": "radar",
    "title": "Team Performance Metrics",
    "axes": axes,
    "values": values
})
print("Radar chart rendered!")
''',
      ),
    ],
  );

  // ── Demo 7: Heatmap ────────────────────────────────────────────

  static const ShowcaseDemo _heatmap = (
    name: 'Heatmap',
    description: 'Renders a correlation heatmap from computed data.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Compute correlation matrix',
        narration: 'Build a correlation matrix and render as a heatmap.',
        code: '''
features = ["Price", "Size", "Rooms", "Age", "Distance"]
# Symmetric correlation matrix (flattened row-major)
corr = [
    1.0, 0.85, 0.72, -0.45, -0.62,
    0.85, 1.0, 0.91, -0.38, -0.55,
    0.72, 0.91, 1.0, -0.28, -0.48,
    -0.45, -0.38, -0.28, 1.0, 0.35,
    -0.62, -0.55, -0.48, 0.35, 1.0,
]

print("Correlation Matrix:")
for i in range(5):
    row = corr[i*5:(i+1)*5]
    parts = []
    for v in row:
        parts.append(str(round(v * 100) / 100))
    vals = " ".join(parts)
    print("  " + features[i] + ": " + vals)

chart_create({
    "type": "heatmap",
    "title": "Feature Correlation Matrix",
    "rows": 5,
    "cols": 5,
    "values": corr,
    "row_labels": features,
    "col_labels": features
})
print("Heatmap rendered!")
''',
      ),
    ],
  );

  // ── Demo 8: Drawing Recognition ────────────────────────────────

  static const ShowcaseDemo _drawingRecognition = (
    name: 'Drawing Recognition',
    description: 'Draw on a canvas, submit, and the LLM identifies the letter.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Capture and recognize drawing',
        narration: 'Subscribe to drawing input, compute fill density, '
            'then ask the LLM.',
        code: r'''
def calculate_density(raw_data):
    data_str = str(raw_data)
    lines = data_str.strip().split("\n")
    filled = 0
    total = 0
    for row in lines:
        for ch in row:
            total = total + 1
            if ch == "#":
                filled = filled + 1
    pct = filled * 100 / total if total > 0 else 0
    return pct

def identify_letter(raw_data):
    prompt = "Analyze this ASCII art drawing:\n\n" + str(raw_data)
    result = str(ask_llm(prompt, "letter-drawing"))
    print("LLM reasoning:")
    print(result)
    # Parse out the final answer
    marker = "FINAL ANSWER:"
    idx = result.find(marker)
    if idx >= 0:
        answer = result[idx + len(marker):].strip()
        return answer[0] if len(answer) > 0 else "?"
    return "?"

def main():
    handle = stream_subscribe("drawing_input")
    print("Waiting for drawing submission...")
    data = stream_next(handle)
    if data is not None:
        print("Received drawing:")
        print(data)
        pct = calculate_density(data)
        print("Fill density: " + str(int(pct)) + "%")
        print("Asking LLM to identify the letter...")
        letter = identify_letter(data)
        print("Identified letter: " + letter)
    else:
        print("No drawing received.")
    stream_close(handle)
    print("Done!")

main()
''',
      ),
    ],
  );

  // ── Demo 9: Form Validation ────────────────────────────────────

  static const ShowcaseDemo _formValidation = (
    name: 'Form Validation',
    description: 'Python creates a form, validates submissions, shows errors.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Create and validate form',
        narration: 'Create a form with fields and validate user input.',
        code: '''
form_id = form_create([
    {"name": "username", "label": "Username", "type": "text"},
    {"name": "email", "label": "Email", "type": "text"},
    {"name": "age", "label": "Age", "type": "number"}
])
print(f"Form created (id={form_id})")

handle = stream_subscribe("form_submissions")
print("Waiting for form submission...")
data = stream_next(handle)
if data is not None:
    print(f"Received: {data}")
    errors = {}
    username = data["username"] if "username" in data else ""
    email = data["email"] if "email" in data else ""
    age = data["age"] if "age" in data else ""
    if len(str(username)) < 3:
        errors["username"] = "Must be at least 3 characters"
    if "@" not in str(email):
        errors["email"] = "Must contain @"
    if errors:
        form_set_errors(form_id, errors)
        print(f"Validation errors: {errors}")
    else:
        print("All fields valid!")
else:
    print("No submission received.")
stream_close(handle)
''',
      ),
    ],
  );

  // ── Demo 12: Tic-Tac-Toe vs LLM ─────────────────────────────

  static const ShowcaseDemo _ticTacToe = (
    name: 'Tic-Tac-Toe',
    description: 'Play tic-tac-toe against the LLM. You are X, LLM is O.',
    steps: [
      ShowcaseDemoStep(
        title: 'Step 1: Play tic-tac-toe',
        narration: 'Tap a cell to place X. The LLM picks its move as O. '
            'Game loops until someone wins or a draw.',
        code: r'''
def format_board(board):
    result = ""
    i = 0
    while i < 3:
        row = ""
        j = 0
        while j < 3:
            cell = board[i * 3 + j]
            if cell == "":
                row = row + str(i * 3 + j + 1)
            else:
                row = row + cell
            if j < 2:
                row = row + " | "
            j = j + 1
        result = result + row + "\n"
        if i < 2:
            result = result + "---------\n"
        i = i + 1
    return result

def check_winner(board):
    lines = [
        [0,1,2], [3,4,5], [6,7,8],
        [0,3,6], [1,4,7], [2,5,8],
        [0,4,8], [2,4,6]
    ]
    for line in lines:
        a = board[line[0]]
        b = board[line[1]]
        c = board[line[2]]
        if a != "" and a == b and b == c:
            return a
    return ""

def count_empty(board):
    n = 0
    for c in board:
        if c == "":
            n = n + 1
    return n

def get_llm_move(board, thread_id):
    board_str = format_board(board)
    prompt = "Current board:\n" + board_str + "\nPick an empty cell number."
    resp = ask_llm(prompt, "tic-tac-toe", thread_id)
    result = str(resp["text"])
    new_tid = resp["thread_id"]
    for ch in result:
        if ch >= "1" and ch <= "9":
            idx = int(ch) - 1
            if board[idx] == "":
                return (idx, new_tid)
    # Fallback: first empty cell
    i = 0
    while i < 9:
        if board[i] == "":
            return (i, new_tid)
        i = i + 1
    return (-1, new_tid)

def main():
    board = ["", "", "", "", "", "", "", "", ""]
    handle = stream_subscribe("ttt_input")
    thread_id = None
    print("Tic-Tac-Toe! You are X, LLM is O.")
    print("Tap a cell to play.")
    print(format_board(board))

    while True:
        data = stream_next(handle)
        if data is None:
            break
        cell = int(str(data))
        if cell < 0 or cell > 8 or board[cell] != "":
            print("Cell occupied, try again.")
            continue
        board[cell] = "X"
        ttt_move(cell, "X")
        print("You played X at " + str(cell + 1))
        print(format_board(board))

        w = check_winner(board)
        if w == "X":
            print("You win!")
            break
        if count_empty(board) == 0:
            print("Draw!")
            break

        print("LLM thinking...")
        move, thread_id = get_llm_move(board, thread_id)
        board[move] = "O"
        ttt_move(move, "O")
        print("LLM played O at " + str(move + 1))
        print(format_board(board))

        w = check_winner(board)
        if w == "O":
            print("LLM wins!")
            break
        if count_empty(board) == 0:
            print("Draw!")
            break

    stream_close(handle)
    print("Game over!")

main()
''',
      ),
    ],
  );
}
