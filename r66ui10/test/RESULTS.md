# Bot AI offline test (R66-ui9)
Each row: averages per fight (60 s max). Threats avoided = player attacks started with the bot in reach that didn't land.

## 1. Attack spam (player presses the same attack every 22 ticks in melee)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 14% | 0.1 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 19 | 39 / 129 | 4/16 |
| Bulwark | Normal | 16% | 0.7 | 0.2 | 1.2 | 0.0 | 0.1 | 0.0 | 17 | 41 / 124 | 3/16 |
| Bulwark | Hard | 16% | 1.1 | 0.8 | 1.6 | 0.0 | 0.1 | 4.1 | 15 | 36 / 128 | 3/16 |
| Tempest | Easy | 41% | 0.4 | 0.1 | 0.3 | 0.0 | 0.0 | 0.0 | 0 | 105 / 77 | 10/16 |
| Tempest | Normal | 49% | 0.4 | 0.1 | 1.8 | 0.0 | 0.0 | 0.0 | 21 | 117 / 43 | 16/16 |
| Tempest | Hard | 51% | 0.5 | 0.4 | 3.9 | 0.0 | 0.0 | 2.0 | 21 | 118 / 33 | 16/16 |
| Solarion | Easy | 43% | 0.2 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 0 | 111 / 83 | 12/16 |
| Solarion | Normal | 49% | 0.4 | 0.0 | 4.0 | 0.0 | 0.0 | 0.0 | 21 | 118 / 60 | 16/16 |
| Solarion | Hard | 42% | 0.8 | 0.9 | 9.2 | 0.0 | 0.0 | 5.0 | 13 | 113 / 72 | 11/16 |
| Wraithstep | Easy | 47% | 0.2 | 0.0 | 0.6 | 0.0 | 0.0 | 0.0 | 27 | 110 / 76 | 11/16 |
| Wraithstep | Normal | 53% | 0.6 | 0.0 | 4.2 | 0.0 | 0.0 | 0.0 | 17 | 111 / 62 | 11/16 |
| Wraithstep | Hard | 51% | 0.8 | 0.3 | 12.2 | 0.0 | 0.0 | 4.2 | 14 | 115 / 59 | 13/16 |

## 2. Flight vs ground (player flies 14 up, 15-20 away, fires ranged)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 25% | 1.1 | 0.6 | 0.5 | 3.5 | 0.2 | 0.0 | 42 | 65 / 137 | 0/8 |
| Bulwark | Normal | 36% | 1.6 | 4.5 | 1.0 | 6.9 | 0.1 | 0.0 | 29 | 73 / 128 | 2/8 |
| Bulwark | Hard | 38% | 1.6 | 8.9 | 2.4 | 8.8 | 0.1 | 1.4 | 15 | 61 / 107 | 4/8 |
| Tempest | Easy | 57% | 0.1 | 0.0 | 0.4 | 1.8 | 0.0 | 0.0 | 0 | 111 / 47 | 7/8 |
| Tempest | Normal | 85% | 0.2 | 0.4 | 1.9 | 2.8 | 0.1 | 0.0 | 29 | 115 / 12 | 8/8 |
| Tempest | Hard | 91% | 0.8 | 0.5 | 4.5 | 4.0 | 0.1 | 0.6 | 16 | 116 / 8 | 8/8 |
| Solarion | Easy | 38% | 0.6 | 0.6 | 0.0 | 5.0 | 0.0 | 0.0 | 38 | 104 / 95 | 5/8 |
| Solarion | Normal | 41% | 1.4 | 2.1 | 0.6 | 14.8 | 0.0 | 0.0 | 27 | 112 / 78 | 8/8 |
| Solarion | Hard | 46% | 1.2 | 4.9 | 2.8 | 20.8 | 0.0 | 1.0 | 19 | 109 / 68 | 6/8 |
| Wraithstep | Easy | 63% | 0.5 | 0.0 | 1.4 | 0.5 | 0.0 | 0.0 | 53 | 93 / 77 | 5/8 |
| Wraithstep | Normal | 27% | 1.0 | 4.8 | 1.5 | 1.6 | 0.0 | 0.0 | 36 | 58 / 99 | 3/8 |
| Wraithstep | Hard | 24% | 1.4 | 13.1 | 5.0 | 2.4 | 0.0 | 0.4 | 25 | 45 / 103 | 1/8 |

## 3. Retreating player (kites at 25-32 studs and casts)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 34% | 0.5 | 1.0 | 0.5 | 0.0 | 0.1 | 0.0 | 50 | 58 / 142 | 0/8 |
| Bulwark | Normal | 35% | 1.1 | 1.1 | 1.2 | 0.0 | 1.2 | 0.0 | 33 | 58 / 124 | 3/8 |
| Bulwark | Hard | 37% | 1.8 | 10.6 | 2.1 | 0.0 | 2.2 | 0.6 | 34 | 56 / 131 | 3/8 |
| Tempest | Easy | 59% | 0.2 | 0.4 | 0.1 | 0.0 | 0.0 | 0.0 | 40 | 107 / 52 | 8/8 |
| Tempest | Normal | 71% | 0.2 | 1.9 | 1.5 | 0.0 | 0.4 | 0.0 | 36 | 102 / 38 | 7/8 |
| Tempest | Hard | 86% | 0.9 | 5.5 | 4.0 | 0.0 | 0.8 | 0.4 | 30 | 110 / 15 | 8/8 |
| Solarion | Easy | 49% | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 107 / 69 | 8/8 |
| Solarion | Normal | 51% | 0.5 | 0.6 | 1.1 | 0.0 | 0.0 | 0.0 | 26 | 107 / 46 | 8/8 |
| Solarion | Hard | 48% | 1.1 | 4.1 | 1.8 | 0.0 | 0.0 | 0.6 | 20 | 106 / 42 | 8/8 |
| Wraithstep | Easy | 70% | 0.5 | 0.0 | 1.1 | 0.0 | 0.0 | 0.0 | 60 | 98 / 64 | 6/8 |
| Wraithstep | Normal | 73% | 0.4 | 1.0 | 6.1 | 0.0 | 0.0 | 0.0 | 29 | 104 / 31 | 7/8 |
| Wraithstep | Hard | 82% | 1.0 | 8.5 | 5.6 | 0.0 | 0.0 | 0.0 | 32 | 86 / 35 | 6/8 |

## 4. Casting player (channels Solar Hammer / Lightning at 12-18)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 59% | 0.4 | 0.1 | 0.4 | 0.0 | 0.1 | 0.0 | 44 | 116 / 29 | 8/8 |
| Bulwark | Normal | 63% | 0.5 | 2.2 | 1.1 | 0.0 | 0.6 | 0.0 | 48 | 113 / 26 | 8/8 |
| Bulwark | Hard | 79% | 1.0 | 3.4 | 3.0 | 0.0 | 1.1 | 0.0 | 39 | 103 / 11 | 8/8 |
| Tempest | Easy | 73% | 0.1 | 0.0 | 0.5 | 0.0 | 0.0 | 0.0 | 31 | 114 / 11 | 8/8 |
| Tempest | Normal | 97% | 0.4 | 0.1 | 1.4 | 0.0 | 0.0 | 0.0 | 22 | 116 / 1 | 8/8 |
| Tempest | Hard | 94% | 0.5 | 0.8 | 3.4 | 0.0 | 0.0 | 0.0 | 16 | 118 / 2 | 8/8 |
| Solarion | Easy | 52% | 0.2 | 0.1 | 0.1 | 0.0 | 0.0 | 0.0 | 30 | 113 / 27 | 8/8 |
| Solarion | Normal | 68% | 1.0 | 1.4 | 1.4 | 0.0 | 0.0 | 0.0 | 43 | 112 / 2 | 8/8 |
| Solarion | Hard | 32% | 1.2 | 7.1 | 1.1 | 0.0 | 0.0 | 0.0 | 32 | 114 / 27 | 8/8 |
| Wraithstep | Easy | 88% | 0.1 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 83 | 112 / 4 | 8/8 |
| Wraithstep | Normal | 100% | 0.0 | 0.6 | 4.4 | 0.0 | 0.0 | 0.0 | 0 | 113 / 0 | 8/8 |
| Wraithstep | Hard | 100% | 0.4 | 0.9 | 12.4 | 0.0 | 0.0 | 0.0 | 15 | 116 / 0 | 8/8 |

## 5. Low health (bot starts at 25% vs spam)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 27% | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0 | 27 / 35 | 1/16 |
| Bulwark | Normal | 14% | 0.4 | 0.1 | 0.3 | 0.0 | 0.0 | 0.0 | 21 | 13 / 37 | 0/16 |
| Bulwark | Hard | 27% | 0.8 | 0.2 | 0.8 | 0.0 | 0.1 | 1.1 | 15 | 16 / 36 | 0/16 |
| Tempest | Easy | 39% | 0.1 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0 | 53 / 28 | 3/16 |
| Tempest | Normal | 45% | 1.8 | 0.0 | 1.0 | 0.0 | 0.0 | 0.0 | 22 | 108 / 9 | 14/16 |
| Tempest | Hard | 38% | 1.8 | 0.2 | 3.0 | 0.0 | 0.0 | 0.4 | 46 | 106 / 15 | 11/16 |
| Solarion | Easy | 38% | 0.4 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 40 | 57 / 32 | 2/16 |
| Solarion | Normal | 35% | 0.9 | 0.2 | 1.1 | 0.0 | 0.0 | 0.0 | 19 | 57 / 31 | 1/16 |
| Solarion | Hard | 14% | 0.9 | 0.9 | 1.0 | 0.0 | 0.0 | 1.9 | 11 | 26 / 33 | 0/16 |
| Wraithstep | Easy | 70% | 0.6 | 0.0 | 0.8 | 0.0 | 0.0 | 0.0 | 15 | 48 / 27 | 1/16 |
| Wraithstep | Normal | 61% | 0.8 | 0.1 | 1.8 | 0.0 | 0.0 | 0.0 | 28 | 50 / 26 | 2/16 |
| Wraithstep | Hard | 64% | 0.9 | 1.6 | 4.2 | 0.0 | 0.0 | 1.4 | 19 | 52 / 26 | 1/16 |

## Cost
BotAI.think: 6.2 microseconds per server tick on average (440829 ticks, this machine, plain Luau).
