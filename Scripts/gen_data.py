import csv, re, sys
d = sys.argv[1]; out = sys.argv[2]
N = 1025
types = {int(r['id']): r['identifier'].capitalize() for r in csv.DictReader(open(f'{d}/types.csv'))}
ptypes = {}
for r in csv.DictReader(open(f'{d}/pokemon_types.csv')):
    pid = int(r['pokemon_id'])
    if pid <= N: ptypes.setdefault(pid, {})[int(r['slot'])] = types[int(r['type_id'])]
genus = {}; names = {}
for r in csv.DictReader(open(f'{d}/pokemon_species_names.csv')):
    if r['local_language_id'] == '9' and int(r['pokemon_species_id']) <= N:
        names[int(r['pokemon_species_id'])] = r['name']; genus[int(r['pokemon_species_id'])] = r['genus']
pref = [10, 11, 9, 8, 7, 12, 14, 13]  # FireRed, LeafGreen, Emerald, Sapphire, Ruby, then later games
flavor = {}
for r in csv.DictReader(open(f'{d}/pokemon_species_flavor_text.csv')):
    sid = int(r['species_id']); v = int(r['version_id'])
    if r['language_id'] != '9' or sid > N: continue
    t = re.sub(r'\s+', ' ', r['flavor_text'].replace('\f', ' ').replace('\n', ' ')).strip()
    t = t.replace('POKéMON', 'Pokémon').replace('POKÉMON', 'Pokémon')
    rank = pref.index(v) if v in pref else 100 + v
    if sid not in flavor or rank < flavor[sid][0]: flavor[sid] = (rank, t)
upper = {n.upper(): n for n in names.values()}
pat = re.compile(r"\b(" + "|".join(re.escape(u) for u in sorted(upper, key=len, reverse=True)) + r")\b")
for sid in flavor: flavor[sid] = (flavor[sid][0], pat.sub(lambda m: upper[m.group(1)], flavor[sid][1]))
for sid in flavor: flavor[sid] = (flavor[sid][0], re.sub(r"\b([A-Z]{2,})\b", lambda m: m.group(1).capitalize(), flavor[sid][1]))
gen = {int(r['id']): int(r['generation_id']) for r in csv.DictReader(open(f'{d}/pokemon_species.csv')) if int(r['id']) <= N}
size = {int(r['species_id']): (int(r['height']), int(r['weight'])) for r in csv.DictReader(open(f'{d}/pokemon.csv')) if r['is_default'] == '1' and int(r['species_id']) <= N}
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
lines = ['// Generated from PokeAPI CSV data (CC BY-SA). Do not edit by hand; see Design/Pokedex.md.',
         'import Foundation', '',
         'extension PokemonSpecies {',
         '  /// name, genus, type 1, type 2 (empty if none), Pokédex entry text, generation, height in dm, weight in hg. Index 0 is No. 001.',
         '  static let data: [(String, String, String, String, String, Int, Int, Int)] = [']
for i in range(1, N + 1):
    t = ptypes[i]
    lines.append(f'    ({q(names[i])}, {q(genus[i])}, {q(t[1])}, {q(t.get(2, ""))}, {q(flavor[i][1])}, {gen[i]}, {size[i][0]}, {size[i][1]}),')
lines += ['  ]', '}', '']
open(out, 'w').write('\n'.join(lines))
print(len(names), len(flavor), 'species;', sum(1 for i in range(1, N+1) if flavor[i][0] < 8), 'with Gen III text')

# Japanese (katakana, language 1) and Korean (language 3) names for the card reader.
ja = {}; ko = {}
for r in csv.DictReader(open(f'{d}/pokemon_species_names.csv')):
    sid = int(r['pokemon_species_id'])
    if sid > N: continue
    if r['local_language_id'] == '1': ja[sid] = r['name']
    if r['local_language_id'] == '3': ko[sid] = r['name']
lines = ['// Generated from PokeAPI pokemon_species_names.csv. Index 0 is No. 001.', 'import Foundation', '',
         'extension PokemonSpecies {', '  /// Japanese and Korean names, used only to read printed card titles.',
         '  static let localizedNames: [(String, String)] = [']
lines += [f'    ({q(ja.get(i, ""))}, {q(ko.get(i, ""))}),' for i in range(1, N + 1)]
lines += ['  ]', '}', '']
open(out.replace('PokemonData.swift', 'PokemonNames.swift'), 'w').write('\n'.join(lines))
print(len(ja), 'ja', len(ko), 'ko')
