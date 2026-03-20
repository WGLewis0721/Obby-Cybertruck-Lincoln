local ShopItems = {
    {
        Name = "Default",
        ProductId = 0,
        Color = Color3.fromRGB(163, 162, 165),
        Pic = "rbxassetid://0",
        Price = 0
    },
    {
        Name = "Green",
        ProductId = 3244954061,
        Color = Color3.fromRGB(0, 255, 0),
        Pic = "rbxassetid://0",
        Price = 50
    },
    {
        Name = "Blue",
        ProductId = 3244953138,
        Color = Color3.fromRGB(0, 85, 255),
        Pic = "rbxassetid://0",
        Price = 50
    },
    {
        Name = "Gold",
        ProductId = 3244953838,
        Color = Color3.fromRGB(255, 215, 0),
        Pic = "rbxassetid://0",
        Price = 50
    },
    -- ── Upgrade items ─────────────────────────────────────────────────────────
    {
        Name = "Speed Boost",
        Type = "Boost",
        ProductId = 0, -- placeholder, replace later
        Description = "Permanent top speed increase for your vehicle",
        Price = 150,
        Pic = "rbxassetid://0"
    },
    -- ── Bundle items ──────────────────────────────────────────────────────────
    {
        Name = "Ultimate Bundle",
        Type = "Bundle",
        ProductId = 0, -- placeholder, replace later
        Description = "Unlock ALL vehicles and ALL paint jobs forever. Best value.",
        Price = 1000,
        Pic = "rbxassetid://0"
    },
}

return ShopItems