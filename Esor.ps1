function inputAndValidTime($Text) {
    $IsValid = $true
    try {
        Write-Host $("" | Out-String)
        $Time = Read-Host $Text
        Write-Host $("" | Out-String)
        $TimeArray = $Time.Split(":")

        if ($Time -notMatch '\d\d:\d\d') {
            Write-Host "Ale podaj prawdziwą godzinę w formacie HH:mm, co? :) (np. 21:36)"
            $IsValid = $false
        }
        if ([int]$TimeArray[0] -lt 0 -or [int]$TimeArray[0] -ge 24) {
            Write-Host "Ale co to za godzina, co? :)"
            $IsValid = $false
        }
        if ([int]$TimeArray[1] -lt 0 -or [int]$TimeArray[1] -ge 60) {
            Write-Host "Z tymi minutami to chyba lekka przesada :)"
            $IsValid = $false
        }
    } catch {
        Write-Host "Ale podaj prawdziwą godzinę w formacie HH:mm, co? :) (np. 21:36)"
        $IsValid = $false
    }
    if (!$IsValid) {
        inputAndValidTime($Text)
    }
    return $Time
}

function inputAndValidDate($Text) {
    $IsValid = $true
    try {
        Write-Host $("" | Out-String)
        $Date = Read-Host $Text
        Write-Host $("" | Out-String)
        $DateArray = $Date.Split("-")
        if ($Date -notMatch '\d\d\d\d-\d\d-\d\d') {
            Write-Host "Ale podaj poprawną datę w formacie yyyy-MM-dd, co? :) (np. 2022-01-31)"
            $IsValid = $false
        }
        if ([int]$DateArray[0] -lt [int]((Get-Date).Year) -or [int]$DateArray[0] -gt ([int]((Get-Date).Year) + 1)) {
            Write-Host "Z tym rokiem to przesadziłeś!"
            $IsValid = $false
        }

        $Date = [DateTime]$Date

        if ($Date -lt (Get-Date)) {
            Write-Host "Ale w przeszłość to my się nie cofamy. :-) Spróbuj ponownie:"
            $IsValid = $false
        }

    } catch {
        Write-Host "Chyba coś nie tak z tą datą. :-) Spróbuj ponownie:"
        $IsValid = $false
    }
    if (!$IsValid) {
        inputAndValidDate($Text)
    }
    return $Date.ToString("yyyy-MM-dd")
}

function showCurrentBusyDates($Headers) {
    $SeasonId = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/seasons/current -Method GET -ContentType 'application/json' -Headers $Headers | Select-Object -ExpandProperty id

    $CurrentBusyDates = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods?seasonId=$SeasonId -Method GET -ContentType 'application/json' -Headers $Headers

    if ($CurrentBusyDates.items.count -gt 0)
    {

        $TableProperty = @{ Expression = { $_.dateFrom }; Label = "Od"; Width = 30 },
        @{ Expression = { $_.dateTo }; Label = "Do"; Width = 30 },
        @{ Expression = { $_.reason }; Label = "Powód"; Width = 30 }

        Write-Host ($CurrentBusyDates.items | Format-Table -Property $TableProperty | Out-String)

    } else {
        Write-Host $("" | Out-String)
        Write-Host "*** Brak zajętych terminów ***" -ForegroundColor Yellow
        Write-Host $("" | Out-String)
    }
}

function addNextMonthWorkDays($Headers) {
    $SeasonId = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/seasons/current -Method GET -ContentType 'application/json' -Headers $Headers | Select-Object -ExpandProperty id

    $CurrentBusyDates = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods?seasonId=$SeasonId -Method GET -ContentType 'application/json' -Headers $Headers

    #    $OperatingMonth = Read-Host "Podaj miesiąc (1-styczeń, 12-grudzień)"
    $OperatingMonth = (Get-Date).Month + 1

    Write-Host "Uzupełnimy dni robocze w miesiącu " -NoNewline; Write-Host(Get-Culture).DateTimeFormat.GetMonthName($OperatingMonth).ToUpper() -ForegroundColor Yellow
    $AcceptCommand = Read-Host "Czy jesteś pewny? (T)ak / (N)ie"

    if ($AcceptCommand -eq "T" -or $AcceptCommand -eq "t") {
        $BusyFromTime = inputAndValidTime("Od której godziny chcesz mieć zajęty termin w dni robocze? (format HH:MM) np. 00:00")

        $BusyToTime = inputAndValidTime("Do której godziny chcesz mieć zajęty termin w dni robocze? (format HH:MM) np. 15:59")

        $Reason = Read-Host "Jaki chcesz mieć powód zajętego terminu? np. Praca"

        $OpearingDate = [DateTime]((Get-Date).Year.toString() + "-" + $OperatingMonth + "-01")
        Write-Host $("" | Out-String)

        while ([int]($OpearingDate.Month) -eq [int]$OperatingMonth) {
            $ToAdd = [PSCustomObject]@{'dateFrom' = $OpearingDate.ToString("yyyy-MM-dd ") + $BusyFromTime;'dateTo' = $OpearingDate.ToString("yyyy-MM-dd ") + $BusyToTime;'reason' = $Reason.ToString()}

            $CurrentBusyDates.items += $ToAdd
            $OpearingDate = $OpearingDate.AddDays(1)
        }

        $Jsonbody= @{
            'seasonId' = $SeasonId
            'periods' = $CurrentBusyDates.items | Sort-Object { $_.dateFrom }
        } | ConvertTo-Json

        Write-Host "*** Trwa wysyłanie, proszę czekać. ***"
        $Response = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods -Method POST -ContentType 'application/json' -Headers $Headers -Body $Jsonbody

        Write-Host $("" | Out-String)
        Write-Host "I to wszystko, godziny uzupełnione.. dobra robota!" -ForegroundColor Yellow
        Write-Host $("" | Out-String)
    }
}

function addSingleBusyDate($Headers) {
    $SeasonId = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/seasons/current -Method GET -ContentType 'application/json' -Headers $Headers | Select-Object -ExpandProperty id

    $CurrentBusyDates = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods?seasonId=$SeasonId -Method GET -ContentType 'application/json' -Headers $Headers

    $BusyDate = inputAndValidDate("Podaj datę, którego dnia chcesz mieć zajęty termin (format yyyy-MM-dd, np. 2022-01-31)")
    $BusyFromTime = inputAndValidTime("Od której godziny chcesz mieć zajęty termin? (format HH:mm, np. 08:05)")

    $BusyToTime = inputAndValidTime("Do której godziny chcesz mieć zajęty termin? (format HH:mm, np. 15:59)")

    $Reason = Read-Host "Jaki chcesz mieć powód zajętego terminu? np. Praca"
    Write-Host $("" | Out-String)

    $ToAdd = [PSCustomObject]@{'dateFrom' = "$BusyDate $BusyFromTime";'dateTo' = "$BusyDate $BusyToTime";'reason' = $Reason.ToString()}

    $CurrentBusyDates.items += $ToAdd

    $Jsonbody= ConvertTo-Json -InputObject @{
        'seasonId' = $SeasonId
        'periods' = @($CurrentBusyDates.items | Sort-Object { $_.dateFrom })
    }

    try
    {
        Write-Host "*** Trwa wysyłanie, proszę czekać. ***"
        $Response = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods -Method POST -ContentType 'application/json' -Headers $Headers -Body $Jsonbody

        Write-Host $("" | Out-String)
        Write-Host "I to wszystko, termin zajęty.. dobra robota!" -ForegroundColor Yellow
        Write-Host $("" | Out-String)
    } catch {
        Write-Host "Coś poszło nie tak podczas wysyłania :c [BD=$BusyDate, BFT=$BusyFromTime, BTT=$BusyToTime, R=$Reason] - wyslij to do Simsa."
        Write-Host $_
    }
}

function deleteAllBusyDates($Headers) {
    $AcceptCommand = Read-Host "Czy na pewno chcesz usunąć wsystkie zajęte terminy? (T)ak / (N)ie"

    if ($AcceptCommand -eq "T" -or $AcceptCommand -eq "t")
    {
        $SeasonId = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/seasons/current -Method GET -ContentType 'application/json' -Headers $Headers | Select-Object -ExpandProperty id

        $Jsonbody = @{
            'seasonId' = $SeasonId
            'periods' = @()
        } | ConvertTo-Json

        try
        {
            Write-Host $( "" | Out-String )
            Write-Host "*** Trwa czyszczenie, proszę czekać. ***"
            $Response = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/periods -Method POST -ContentType 'application/json' -Headers $Headers -Body $Jsonbody

            Write-Host $( "" | Out-String )
            Write-Host "Wyczyszczone!" -ForegroundColor Yellow
            Write-Host $( "" | Out-String )
        }
        catch {
            Write-Host "Coś poszło nie tak podczas wysyłania :c [BD=$BusyDate, BFT=$BusyFromTime, BTT=$BusyToTime, R=$Reason] - wyslij to do Simsa."
            Write-Host $_
        }
    }
}

function getDecision() {
    $possibleDecisions = (0,1,2,3,9)
    try
    {
        Write-Host "=======================MENU======================="
        Write-Host "Co chcesz zrobić:"
        Write-Host "[1] - Pokaż aktualnie zajęte terminy"
        Write-Host "[2] - Uzupełnij dni robocze na przyszły miesiąc"
        Write-Host "[3] - Dodaj zajęty termin konkretnego dnia"
        Write-Host "[9] - " -NoNewline; Write-Host "Usuń wszystkie zajęte terminy" -ForegroundColor Red
        Write-Host "[0] - wyjdź"
        Write-Host "=================================================="

        Write-Host $( "" | Out-String )
        $Command = Read-Host "Wprowadź cyfrę"
        if ($possibleDecisions -notcontains $Command) {
            Write-Host $("" | Out-String)
            getDecision
        }
    } catch {
        Write-Host "Coś poszło nie tak, jeszcze raz."
        getDecision
    }
    return $Command
}

function getTokenByAuthorization() {
    try
    {
        Write-Host "Zalogujmy się do Esora.."

        $Login = Read-Host "Podaj swojego maila"
        $Password = Read-Host -AsSecureString "Podaj hasło"

        $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $PasswordValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)

        $PostParams = @{ "login" = $Login.Trim(); "password" = "$PasswordValue" }

        $LoginResponse = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/login -Method POST -Body $PostParams

        return $LoginResponse.token.ToString()

    } catch {
        Write-Host $("" | Out-String)
        Write-Host "Niestety niepoprawny login lub hasło :("
        Write-Host "Spróbuj ponownie"
        Write-Host $("" | Out-String)

        getTokenByAuthorization
    }
}

Write-Host "Cześć, tu "-NoNewline; Write-Host "Sims" -ForegroundColor Green -NoNewline; Write-Host "."
Write-Output "Witam Cię w moim autorskim uzupełniaczu zajętych godzin w dni Esorze, wersja 1.0."
Write-Output "Ewentualne błędy w aplikacji proszę zgłaszać poprzez maila, bądź na fb. :-)"
Write-Host $("" | Out-String)
Write-Output "Dobra.. to lecimy!"
Write-Host $("" | Out-String)

try {
    $Token = getTokenByAuthorization

    $Headers = @{
        Authorization="Bearer $Token"
    }

    $UserName = Invoke-RestMethod -Uri https://sedzia.pzkosz.pl/api/me -Method GET -ContentType 'application/json' -Headers $Headers | Select-Object -ExpandProperty username

    Write-Host $("" | Out-String)

    Write-Host "No witaj " -NoNewline; Write-Host "$UserName!" -ForegroundColor Yellow


    while ($true) {
        Write-Host $("" | Out-String)
        $Command = getDecision
        Write-Host $("" | Out-String)

        switch($Command)
        {
            1 {showCurrentBusyDates($Headers)}
            2 {addNextMonthWorkDays($Headers)}
            3 {addSingleBusyDate($Headers)}
            9 {deleteAllBusyDates($Headers)}
            0 {
                Write-Host "Dzięki za skorzystanie! Dobrego dnia!"
                Start-Sleep -s 2
                Exit
            }
        }
    }
} catch {
    Read-Host -Prompt "Coś poszło nie tak :( Skontaktuj się z Simsem! Wciśnij ENTER żeby wyjść"
    Write-Host $_
}
