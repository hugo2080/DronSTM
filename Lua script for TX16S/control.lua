-- === Stałe komendy i konfiguracja ===
local CMD_ACK = "CMD=ACK"  -- Komenda ACK do wysyłki przez Crossfire
local CMD_NO  = "CMD=NO"   -- Komenda NO do wysyłki przez Crossfire

-- Wymiary przycisków dotykowych
local BUTTON_WIDTH = 80
local BUTTON_HEIGHT = 50

-- Definicje przycisków "TAK" i "NIE" z ich pozycjami i etykietami
local BUTTON_TAK = { x = 90,  y = 140, label = "TAK" }
local BUTTON_NIE = { x = 270, y = 140, label = "NIE" }

-- === Zmienne stanu ===
local fieldValue = 0       -- Odczytana wartość z ADC1
local confirmed = nil      -- Flaga potwierdzenia wyboru
local lastPressed = nil    -- Ostatnio naciśnięty przycisk
local dataSaved = false    -- Status zapisu danych
local state = "ASK"        -- Stan aplikacji: "ASK" lub "SAVED"

-- === Backend ===

--- Odczytuje wartość z kanału ADC1 i zapisuje do zmiennej fieldValue
local function readTelemetry()
  local val = getValue("ADC1")
  if val then fieldValue = val end
end

--- Wysyła komendę przez Crossfire telemetry push
-- @param cmd (string) - Komenda do wysłania (np. CMD_ACK lub CMD_NO)
local function sendCommand(cmd)
  crossfireTelemetryPush(0x7A, cmd)
end

--- Zapisuje odczytaną wartość fieldValue do pliku na karcie SD
-- Zapis odbywa się w trybie "append", dane nie są nadpisywane
local function saveData()
  local file = io.open("/SCRIPTS/TELEMETRY/data_log.txt", "a")
  if file then
    io.write(file, string.format("ADC1=%d\n", fieldValue))
    io.close(file)
    dataSaved = true
  else
    dataSaved = false
  end
end

-- === UI ===

--- Sprawdza, czy współrzędne dotyku mieszczą się w obszarze danego przycisku
-- @param button (table) - Obiekt przycisku z polami x, y
-- @param x (number), y (number) - Współrzędne dotyku
-- @return boolean - true jeśli dotknięto przycisku
local function isTouched(button, x, y)
  return (x >= button.x) and (x <= button.x + BUTTON_WIDTH) and
         (y >= button.y) and (y <= button.y + BUTTON_HEIGHT)
end

--- Rysuje pojedynczy przycisk
-- @param button (table) - Obiekt przycisku
-- @param active (boolean) - Czy przycisk jest aktywny (zaznaczony)
local function drawButton(button, active)
  local color = active and SOLID or GREY_DEFAULT
  lcd.drawFilledRectangle(button.x, button.y, BUTTON_WIDTH, BUTTON_HEIGHT, color)
  lcd.drawRectangle(button.x, button.y, BUTTON_WIDTH, BUTTON_HEIGHT, SOLID)
  lcd.drawText(button.x + 25, button.y + 15, button.label, SMLSIZE + INVERS)
end

--- Rysuje interfejs użytkownika dla stanu "ASK"
local function drawMainUI()
  lcd.drawRectangle(10, 5, LCD_W - 5, LCD_H - 10)
  lcd.drawText(25, 10, "POMIAR PARAMETRÓW WODY", DBLSIZE)
  lcd.drawText(40, 60, string.format("Przewodność: %d", fieldValue), MIDSIZE)
  lcd.drawText(140, 100, "Czy kontynuować?", MIDSIZE)
  drawButton(BUTTON_TAK, lastPressed == "TAK")
  drawButton(BUTTON_NIE, lastPressed == "NIE")
end

--- Rysuje komunikat po zapisaniu danych
local function drawSavedUI()
  if dataSaved then
    lcd.drawText(90, 120, "Dane zapisane!", DBLSIZE)
  else
    lcd.drawText(90, 120, "Błąd zapisu!", DBLSIZE)
  end
  lcd.drawText(30, 180, "Nowy pomiar - [ENT] Wyjdź - [EXIT]", SMLSIZE)
end

-- === Obsługa zdarzeń ===

--- Obsługuje dotyk na ekranie dotykowym
-- @param event (number) - Typ zdarzenia (np. EVT_TOUCH_TAP)
-- @param touchState (table) - Współrzędne dotyku
local function handleTouch(event, touchState)
  if event == EVT_TOUCH_TAP and touchState then
    if isTouched(BUTTON_TAK, touchState.x, touchState.y) then
      confirmed = true
      lastPressed = "TAK"
      sendCommand(CMD_ACK)
      saveData()
      state = "SAVED"
    elseif isTouched(BUTTON_NIE, touchState.x, touchState.y) then
      confirmed = false
      lastPressed = "NIE"
      sendCommand(CMD_NO)
    end
  end
end

--- Obsługuje naciśnięcia fizycznych przycisków ENTER i EXIT
-- @param event (number) - Typ zdarzenia
local function handleButtons(event)
  if event == EVT_ENTER_BREAK then
    confirmed = true
    lastPressed = "TAK"
    sendCommand(CMD_ACK)
    saveData()
    state = "SAVED"
  elseif event == EVT_EXIT_BREAK then
    confirmed = false
    lastPressed = "NIE"
    sendCommand(CMD_NO)
  end
end

-- === Główna funkcja uruchomieniowa ===

--- Główna funkcja wywoływana cyklicznie przez LUA na radiu
-- Obsługuje stany interfejsu, aktualizuje ekran i przetwarza dane
-- @param event (number) - Zdarzenie systemowe
-- @param touchState (table) - Informacje o dotyku (jeśli dostępne)
-- @return number - 1 jeśli użytkownik wybrał zakończenie, w przeciwnym razie 0
local function run(event, touchState)
  if event == EVT_SYS_FIRST or event == EVT_MODEL_FIRST or event == EVT_TELEMETRY_FIRST then
    return event
  end

  lcd.clear()
  readTelemetry()

  if state == "ASK" then
    drawMainUI()
    handleTouch(event, touchState)
    handleButtons(event)
  elseif state == "SAVED" then
    drawSavedUI()
    if event == EVT_ENTER_BREAK then
      state = "ASK"
      confirmed = nil
      lastPressed = nil
      dataSaved = false
    elseif event == EVT_EXIT_BREAK then
      return 1
    end
  end

  return 0
end

-- Eksport funkcji run jako głównego punktu wejścia dla LUA
return { run = run }
