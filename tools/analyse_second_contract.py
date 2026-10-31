#!/usr/bin/env python3
"""Record hypotheses for the unconfirmed structure-03 extension, never app facts."""
import datetime as dt, json, sys
r=json.load(open(sys.argv[1])); values={e['response'] for e in r['exchanges'] if e['operation']=='READ PATH 20002030 / 2' and e['statusWord']=='9000'}
if len(values)!=1:raise SystemExit('Missing/conflicting explicit record')
h=values.pop();b=''.join(f'{int(c,16):04b}' for c in h)
def value(start,width):return int(b[start:start+width],2)
print('# Hypothèse de structure du second contrat\n')
print('Le tronc commun occupe 69 bits. Le format complémentaire 03 n’est pas documenté dans les sources accessibles. Les lectures ci-dessous sont des extractions de motifs, PAS des champs métier confirmés.\n')
print('| Position | Largeur | Valeur | Comparaison / hypothèse |\n|---|---:|---:|---|')
for start,width,label in [(69,16,'origine possible, lieu non identifié'),(85,16,'même valeur que le lieu 13143 des validations confirmées à Toulon'),(101,14,'si date Intercode : '+str(dt.date(1997,1,1)+dt.timedelta(days=value(101,14)))+' ; même jour de vente que le titre 5'),(115,16,'même valeur que le code appareil de vente 67 du titre 5'),(131,8,'champ éventuel inconnu'),(216,16,'fin non nulle : sens inconnu')]:
 print(f'| {start} | {width} | {value(start,width)} | {label} |')
print('\nCes concordances motivent la piste d’un droit associé à un trajet déclaré ou à la même vente, sans identifier un abonnement bus ni une validation. La valeur 40 finale ne doit pas être appelée ligne, montant ou compteur sans schéma.')
