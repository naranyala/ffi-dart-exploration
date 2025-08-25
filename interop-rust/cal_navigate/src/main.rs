use chrono::{Datelike, Duration, Local, NaiveDate, Weekday};
use crossterm::{
    cursor,
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    style::{Attribute, Print, SetAttribute},
    terminal::{self, ClearType},
};
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    terminal::enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, cursor::Hide)?;

    let original_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        let _ = terminal::disable_raw_mode();
        let _ = execute!(io::stdout(), cursor::Show);
        original_hook(panic_info);
    }));

    let result = run_calendar();

    terminal::disable_raw_mode()?;
    execute!(stdout, cursor::Show)?;
    clear_screen(&mut stdout)?;
    execute!(stdout, cursor::MoveTo(0, 0))?;

    result
}

fn run_calendar() -> Result<(), Box<dyn std::error::Error>> {
    let mut stdout = io::stdout();
    let today = Local::now().date_naive();
    let mut selected = today;
    let mut current_month_start =
        NaiveDate::from_ymd_opt(today.year(), today.month(), 1).expect("Invalid date");

    loop {
        render(&mut stdout, current_month_start, selected)?;

        if let Event::Key(key_event) = event::read()? {
            match handle_key(key_event, selected) {
                KeyAction::Quit => break,
                KeyAction::Navigate(new_selected) => {
                    selected = new_selected;
                    current_month_start =
                        NaiveDate::from_ymd_opt(selected.year(), selected.month(), 1)
                            .expect("Invalid date");
                }
                KeyAction::Today => {
                    selected = today;
                    current_month_start = NaiveDate::from_ymd_opt(today.year(), today.month(), 1)
                        .expect("Invalid date");
                }
                KeyAction::None => {}
            }
        }
    }

    Ok(())
}

#[derive(Debug)]
enum KeyAction {
    Quit,
    Navigate(NaiveDate),
    Today,
    None,
}

fn handle_key(key_event: KeyEvent, selected: NaiveDate) -> KeyAction {
    match key_event.code {
        KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc => KeyAction::Quit,
        KeyCode::Char('t') | KeyCode::Char('T') => KeyAction::Today,
        KeyCode::Left => selected
            .checked_sub_signed(Duration::days(1))
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        KeyCode::Right => selected
            .checked_add_signed(Duration::days(1))
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        KeyCode::Up => selected
            .checked_sub_signed(Duration::days(7))
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        KeyCode::Down => selected
            .checked_add_signed(Duration::days(7))
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        // Year jump
        KeyCode::PageUp => add_months(selected, -12)
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        KeyCode::PageDown => add_months(selected, 12)
            .map(KeyAction::Navigate)
            .unwrap_or(KeyAction::None),
        _ => KeyAction::None,
    }
}

fn render(stdout: &mut io::Stdout, month_start: NaiveDate, selected: NaiveDate) -> io::Result<()> {
    // Layout constants
    const GRID_COLS: u16 = 7;
    const CELL_W: u16 = 3; // "dd" + optional space (no trailing space on last col)
    const TITLE_Y: u16 = 0;
    const WEEKDAY_Y: u16 = 1;
    const GRID_Y: u16 = 2;
    const GRID_ROWS: u16 = 6;

    // Visible width (no trailing space on last column)
    let total_cols: u16 = GRID_COLS * CELL_W - 1;

    // Full-screen clear and home cursor
    clear_screen(stdout)?;
    execute!(stdout, cursor::MoveTo(0, 0))?;

    let year = month_start.year();
    let month = month_start.month();
    let first_day = NaiveDate::from_ymd_opt(year, month, 1).expect("Invalid first day");
    let days_in_month = days_in_month(year, month);
    let start_weekday = sunday_start_index(first_day.weekday());

    // Title centered within total_cols
    let title = format!("{} {}", month_name(month), year);
    let pad = total_cols
        .saturating_sub(title.len() as u16)
        .saturating_div(2) as usize;
    execute!(stdout, cursor::MoveTo(0, TITLE_Y), Print(" ".repeat(pad)))?;
    execute!(stdout, Print(&title))?;
    execute!(stdout, Print("\n"))?;

    // Weekday header
    execute!(stdout, cursor::MoveTo(0, WEEKDAY_Y))?;
    execute!(stdout, Print("Su Mo Tu We Th Fr Sa"))?;

    // Clear grid area to avoid artifacts
    for r in 0..GRID_ROWS {
        execute!(
            stdout,
            cursor::MoveTo(0, GRID_Y + r),
            Print(" ".repeat(total_cols as usize))
        )?;
    }

    // Render days
    for day in 1..=days_in_month {
        let idx = start_weekday as u32 + (day - 1);
        let row = (idx / 7) as u16;
        let col = (idx % 7) as u16;

        let x = col * CELL_W;
        let y = GRID_Y + row;

        let current_date = NaiveDate::from_ymd_opt(year, month, day).expect("Invalid day");
        let is_selected = current_date == selected;

        execute!(stdout, cursor::MoveTo(x, y))?;

        // Print 2-char day, style-safe, then optional space (not after last column)
        if is_selected {
            execute!(stdout, SetAttribute(Attribute::Reverse))?;
        }
        execute!(stdout, Print(format!("{:>2}", day)))?;
        if is_selected {
            execute!(stdout, SetAttribute(Attribute::Reset))?;
        }

        if col < GRID_COLS - 1 {
            execute!(stdout, Print(" "))?;
        }
    }

    // Legend
    let weeks_used = ((start_weekday as u32 + days_in_month + 6) / 7) as u16;
    let legend_y = GRID_Y + weeks_used + 1;
    execute!(
        stdout,
        cursor::MoveTo(0, legend_y),
        Print("←/→ day  ↑/↓ week  PgUp/PgDn year  t today  q quit")
    )?;

    stdout.flush()?;
    Ok(())
}

fn add_months(date: NaiveDate, delta_months: i32) -> Option<NaiveDate> {
    let mut year = date.year();
    let mut month = date.month() as i32 + delta_months;

    while month <= 0 {
        month += 12;
        year -= 1;
    }
    while month > 12 {
        month -= 12;
        year += 1;
    }

    let target_month = month as u32;
    let target_day = date.day().min(days_in_month(year, target_month));
    NaiveDate::from_ymd_opt(year, target_month, target_day)
}

fn days_in_month(year: i32, month: u32) -> u32 {
    let (next_year, next_month) = if month == 12 {
        (year + 1, 1)
    } else {
        (year, month + 1)
    };
    NaiveDate::from_ymd_opt(next_year, next_month, 1)
        .expect("Invalid next month")
        .pred_opt()
        .expect("No previous day")
        .day()
}

fn month_name(month: u32) -> &'static str {
    match month {
        1 => "January",
        2 => "February",
        3 => "March",
        4 => "April",
        5 => "May",
        6 => "June",
        7 => "July",
        8 => "August",
        9 => "September",
        10 => "October",
        11 => "November",
        12 => "December",
        _ => "Unknown",
    }
}

fn sunday_start_index(weekday: Weekday) -> u8 {
    match weekday {
        Weekday::Sun => 0,
        Weekday::Mon => 1,
        Weekday::Tue => 2,
        Weekday::Wed => 3,
        Weekday::Thu => 4,
        Weekday::Fri => 5,
        Weekday::Sat => 6,
    }
}

fn clear_screen(stdout: &mut io::Stdout) -> io::Result<()> {
    execute!(stdout, terminal::Clear(ClearType::All))
}
