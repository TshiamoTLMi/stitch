# Independent validation of the generated DLS seed dataset.
#
# Re-derives the expected enums from the taxonomy source and asserts the
# dataset is 100% aligned, unique, and backed by local image files.
# Run from the package root:  pwsh -File tooling\seed_generator\validate_seed.ps1
param(
  [string]$SeedPath     = "assets/seed/wardrobe_seed.json",
  [string]$TaxonomyPath = "lib/core/constants/wardrobe_taxonomy.dart",
  [int]$MinItems        = 300
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SeedPath))     { throw "Seed file not found: $SeedPath" }
if (-not (Test-Path $TaxonomyPath)) { throw "Taxonomy not found: $TaxonomyPath" }

$taxRaw   = Get-Content $TaxonomyPath -Raw
$seedData = Get-Content $SeedPath -Raw | ConvertFrom-Json
$items    = @($seedData.items)

$parents = @('Tops','Bottoms','Dresses & Jumpsuits','Outerwear',
             'Activewear & Leisure','Essentials & Intimates','Accessories','Footwear')
$colors  = @('black','white','grey','navy','brown','beige','olive','blue',
             'green','red','pink','purple','yellow','orange','cream','tan')
$styles  = @('formal','casual','streetwear','smart_casual','sportswear')
$seasons = @('All Season','Summer','Winter','Spring','Autumn')
$groups  = @('neutral','warm','cool')
$statuses= @('clean','in_wash')
$genders = @('Unisex','Menswear','Womenswear')
$types   = @('top','bottom','full','shoes','accessory')

# UUIDv5: version nibble 5, variant in [89ab]
$uuidV5  = '^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'

$errors = New-Object System.Collections.Generic.List[string]

if ($items.Count -lt $MinItems) { $errors.Add("item count $($items.Count) < $MinItems") }

$ids = @($items | ForEach-Object { $_.id } | Sort-Object -Unique)
if ($ids.Count -ne $items.Count) { $errors.Add("duplicate ids: $($items.Count - $ids.Count)") }

foreach ($it in $items) {
  $id = $it.id
  if ($id -notmatch $uuidV5)            { $errors.Add("non-UUIDv5 id: $id") }
  if ($parents -notcontains $it.parentCategory) { $errors.Add("parent '$($it.parentCategory)'") }
  if ($taxRaw -notmatch [regex]::Escape("'$($it.subcategory)'")) { $errors.Add("subcategory not in taxonomy: $($it.subcategory)") }
  if ($types  -notcontains $it.categoryType)  { $errors.Add("categoryType '$($it.categoryType)' ($id)") }
  if ($colors -notcontains $it.color)    { $errors.Add("color '$($it.color)' ($id)") }
  if ($groups -notcontains $it.colorGroup){ $errors.Add("colorGroup '$($it.colorGroup)' ($id)") }
  if ($seasons -notcontains $it.season)  { $errors.Add("season '$($it.season)' ($id)") }
  if ($statuses -notcontains $it.status) { $errors.Add("status '$($it.status)' ($id)") }
  if ($genders -notcontains $it.gender)  { $errors.Add("gender '$($it.gender)' ($id)") }
  if (@($it.styleTags).Count -eq 0)      { $errors.Add("no styleTags ($id)") }
  foreach ($s in $it.styleTags) {
    if ($styles -notcontains $s) { $errors.Add("style '$s' ($id)") }
  }
  if ([string]::IsNullOrWhiteSpace($it.localImagePath)) { $errors.Add("no localImagePath ($id)") }
  elseif (-not (Test-Path $it.localImagePath))          { $errors.Add("missing local image: $($it.localImagePath)") }
  if ($it.userId -ne 'seed') { $errors.Add("userId '$($it.userId)' ($id)") }
}

Write-Host "items            : $($items.Count)"
Write-Host "unique ids       : $($ids.Count)"
Write-Host "parents          : $(@($items.parentCategory | Sort-Object -Unique).Count)"
Write-Host "subcategories    : $(@($items.subcategory | Sort-Object -Unique).Count)"
Write-Host "colors           : $(@($items.color | Sort-Object -Unique).Count)"
Write-Host "color groups     : $(@($items.colorGroup | Sort-Object -Unique) -join ', ')"
Write-Host "style tags       : $(@($items.styleTags | Sort-Object -Unique) -join ', ')"
Write-Host "seasons          : $(@($items.season | Sort-Object -Unique).Count)"
Write-Host "unique local imgs: $(@($items.localImagePath | Sort-Object -Unique).Count)"

Write-Host "`ndistribution:"
$items | Group-Object parentCategory | Sort-Object Name | ForEach-Object {
  Write-Host ("  {0,-24} {1}" -f $_.Name, $_.Count)
}

if ($errors.Count -gt 0) {
  Write-Host "`nVALIDATION FAILED ($($errors.Count) problems):" -ForegroundColor Red
  $errors | Select-Object -First 25 | ForEach-Object { Write-Host "  - $_" }
  exit 1
}

Write-Host "`nVALIDATION PASSED: dataset is 100% taxonomy-aligned, unique, and fully backed by local images." -ForegroundColor Green
exit 0
