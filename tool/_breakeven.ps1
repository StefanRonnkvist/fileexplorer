# Break-even fare analysis for airline fleet.
# Models one max-range flight, minimum Main seats, using the game's exact formulas.

$cruise = 600.0          # mph
$fuelPrice = 8.0         # $/gallon
$hoursPerWorkDay = 8.0
$pilotsPerFlight = 2
$paxPerAttendant = 50
$daysPerMonth = 30
$monthlyHoursCap = 160
$annualHours = 2080.0

# Seattle hub MII -> base hourly wage
$mii = 0.9 * 56012000000.0 / 737000.0
$baseWage = $mii / $annualHours
$mult = @{ 'Pilot' = 4.0; 'Flight Attendant' = 1.12; 'Mechanic' = 1.36; 'Agent' = 0.62; 'Administration' = 1.0 }
$rolePercent = @{ 'Agent' = 15; 'Mechanic' = 10; 'Flight Attendant' = 21; 'Pilot' = 18; 'Administration' = 36 }
$crewPercent = 18 + 21

# Fleet: name, minSeats(seats lower bound), range, fuel gallons capacity
$fleet = @(
  @{ name = 'Regional Jet';        seats = 50;  range = 1800;  fuel = 6000 },
  @{ name = 'Narrow-Body';         seats = 100; range = 3600;  fuel = 8000 },
  @{ name = 'Wide-Body';           seats = 250; range = 9000;  fuel = 80000 },
  @{ name = 'Very Large Aircraft'; seats = 400; range = 12000; fuel = 100000 }
)

foreach ($a in $fleet) {
  $t = $a.range / $cruise            # flight hours
  $shifts = [Math]::Max(1, [Math]::Ceiling($t / $hoursPerWorkDay))
  $pilots = $shifts * $pilotsPerFlight
  $attendants = $shifts * [Math]::Ceiling($a.seats / $paxPerAttendant)
  $crew = $pilots + $attendants
  $totalEmp = [Math]::Round($crew * 100.0 / $crewPercent)

  # Monthly wage expense (all roles) from totalEmp
  $wage = 0.0
  foreach ($r in $rolePercent.Keys) {
    $personnel = if ($r -eq 'Pilot') { $pilots } elseif ($r -eq 'Flight Attendant') { $attendants } else { [Math]::Round($totalEmp * $rolePercent[$r] / 100.0) }
    $wage += $personnel * $monthlyHoursCap * ($baseWage * $mult[$r])
  }
  # Per-flight crew cost: allocate one month's wages over the flights a month this
  # aircraft could fly. Max flights/month = 30 days * (24h / flight hours).
  $flightsPerMonth = $daysPerMonth * (24.0 / $t)
  $crewPerFlight = $wage / $flightsPerMonth

  $fuelGal = $a.fuel                 # distance == range at max range
  $fuelCost = $fuelGal * $fuelPrice

  $cost = $crewPerFlight + $fuelCost
  $be = $cost / $a.seats

  "{0,-20} t={1,5:N2}h shifts={2} crew={3,3} emp={4,4} wage/mo={5,12:N0} fl/mo={6,7:N1} crew/flt={7,9:N0} fuel={8,9:N0} cost/flt={9,10:N0} BE/main={10,6:N0}" -f `
    $a.name, $t, $shifts, $crew, $totalEmp, $wage, $flightsPerMonth, $crewPerFlight, $fuelCost, $cost, $be
}
"Base hourly wage: {0:N2}" -f $baseWage
"Seattle MII: {0:N0}" -f $mii
