# Bot AI offline test (R66-ui11b)
Each row: averages per fight (60 s max). Threats avoided = player attacks started with the bot in reach that didn't land.

## 1. Attack spam (player presses the same attack every 22 ticks in melee)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 13% | 0.1 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 47 | 45 / 121 | 4/16 |
| Bulwark | Normal | 13% | 0.2 | 0.0 | 0.4 | 0.0 | 0.0 | 0.0 | 30 | 39 / 128 | 3/16 |
| Bulwark | Hard | 17% | 0.9 | 0.1 | 1.1 | 0.0 | 0.1 | 0.0 | 18 | 43 / 126 | 3/16 |
| Tempest | Easy | 31% | 0.3 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 82 / 107 | 3/16 |
| Tempest | Normal | 44% | 0.2 | 0.0 | 0.4 | 0.0 | 0.0 | 0.0 | 0 | 115 / 66 | 14/16 |
| Tempest | Hard | 51% | 0.1 | 0.1 | 2.1 | 0.0 | 0.0 | 0.0 | 18 | 117 / 47 | 16/16 |
| Solarion | Easy | 31% | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 83 / 118 | 1/16 |
| Solarion | Normal | 48% | 0.1 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 16 | 117 / 73 | 15/16 |
| Solarion | Hard | 54% | 0.2 | 0.0 | 4.2 | 0.0 | 0.0 | 0.0 | 20 | 118 / 52 | 16/16 |
| Wraithstep | Easy | 41% | 0.1 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0 | 69 / 103 | 0/16 |
| Wraithstep | Normal | 47% | 0.1 | 0.0 | 0.5 | 0.0 | 0.0 | 0.0 | 34 | 110 / 76 | 11/16 |
| Wraithstep | Hard | 50% | 0.4 | 0.0 | 3.6 | 0.0 | 0.0 | 0.0 | 24 | 116 / 60 | 13/16 |

## 2. Flight vs ground (player flies 14 up, 15-20 away, fires ranged)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 18% | 0.1 | 0.0 | 0.0 | 1.0 | 0.0 | 0.0 | 60 | 64 / 136 | 1/8 |
| Bulwark | Normal | 28% | 0.8 | 0.4 | 0.2 | 1.9 | 0.1 | 0.0 | 49 | 72 / 131 | 1/8 |
| Bulwark | Hard | 29% | 1.5 | 3.6 | 1.2 | 5.6 | 0.1 | 0.0 | 32 | 66 / 132 | 3/8 |
| Tempest | Easy | 22% | 0.0 | 0.2 | 0.0 | 1.8 | 0.0 | 0.0 | 0 | 72 / 102 | 2/8 |
| Tempest | Normal | 55% | 0.4 | 0.1 | 0.9 | 2.1 | 0.0 | 0.0 | 27 | 113 / 46 | 8/8 |
| Tempest | Hard | 91% | 0.2 | 0.2 | 2.8 | 2.8 | 0.1 | 0.0 | 27 | 115 / 6 | 8/8 |
| Solarion | Easy | 31% | 0.0 | 0.0 | 0.0 | 1.2 | 0.0 | 0.0 | 0 | 103 / 111 | 4/8 |
| Solarion | Normal | 45% | 0.6 | 0.4 | 0.2 | 3.2 | 0.0 | 0.0 | 41 | 110 / 85 | 6/8 |
| Solarion | Hard | 52% | 0.9 | 1.0 | 1.0 | 12.1 | 0.0 | 0.0 | 24 | 115 / 69 | 8/8 |
| Wraithstep | Easy | 47% | 0.1 | 0.0 | 0.2 | 0.1 | 0.0 | 0.0 | 0 | 62 / 110 | 0/8 |
| Wraithstep | Normal | 67% | 0.8 | 0.1 | 0.4 | 0.8 | 0.0 | 0.0 | 47 | 101 / 67 | 6/8 |
| Wraithstep | Hard | 36% | 1.1 | 3.5 | 2.2 | 1.2 | 0.0 | 0.0 | 39 | 76 / 90 | 4/8 |

## 3. Retreating player (kites at 25-32 studs and casts)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 27% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 53 / 140 | 0/8 |
| Bulwark | Normal | 28% | 0.6 | 0.8 | 0.1 | 0.0 | 0.2 | 0.0 | 60 | 59 / 139 | 1/8 |
| Bulwark | Hard | 25% | 1.0 | 2.9 | 0.4 | 0.0 | 0.9 | 0.0 | 44 | 45 / 138 | 1/8 |
| Tempest | Easy | 51% | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 89 / 66 | 5/8 |
| Tempest | Normal | 52% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 100 / 59 | 7/8 |
| Tempest | Hard | 72% | 0.4 | 1.6 | 1.2 | 0.0 | 0.0 | 0.0 | 43 | 97 / 35 | 7/8 |
| Solarion | Easy | 35% | 0.2 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 97 / 102 | 4/8 |
| Solarion | Normal | 52% | 0.0 | 0.2 | 0.2 | 0.0 | 0.0 | 0.0 | 0 | 107 / 54 | 8/8 |
| Solarion | Hard | 45% | 0.4 | 1.2 | 1.1 | 0.0 | 0.0 | 0.0 | 24 | 106 / 47 | 8/8 |
| Wraithstep | Easy | 52% | 0.0 | 0.0 | 0.5 | 0.0 | 0.0 | 0.0 | 0 | 55 / 112 | 0/8 |
| Wraithstep | Normal | 72% | 0.2 | 0.4 | 1.6 | 0.0 | 0.0 | 0.0 | 42 | 108 / 65 | 8/8 |
| Wraithstep | Hard | 75% | 0.4 | 1.0 | 4.6 | 0.0 | 0.0 | 0.0 | 24 | 100 / 36 | 7/8 |

## 4. Casting player (channels Solar Hammer / Lightning at 12-18)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 26% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 110 / 58 | 6/8 |
| Bulwark | Normal | 41% | 0.5 | 0.2 | 0.4 | 0.0 | 0.1 | 0.0 | 43 | 118 / 50 | 8/8 |
| Bulwark | Hard | 67% | 1.0 | 1.0 | 1.0 | 0.0 | 0.5 | 0.0 | 48 | 110 / 22 | 8/8 |
| Tempest | Easy | 47% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 116 / 36 | 8/8 |
| Tempest | Normal | 79% | 0.1 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 48 | 116 / 8 | 8/8 |
| Tempest | Hard | 87% | 0.2 | 0.1 | 2.1 | 0.0 | 0.0 | 0.0 | 26 | 118 / 4 | 8/8 |
| Solarion | Easy | 25% | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 102 / 62 | 4/8 |
| Solarion | Normal | 70% | 0.5 | 0.1 | 0.1 | 0.0 | 0.0 | 0.0 | 37 | 113 / 14 | 8/8 |
| Solarion | Hard | 63% | 0.8 | 1.9 | 1.5 | 0.0 | 0.0 | 0.0 | 32 | 113 / 12 | 8/8 |
| Wraithstep | Easy | 55% | 0.1 | 0.1 | 0.1 | 0.0 | 0.0 | 0.0 | 77 | 102 / 52 | 5/8 |
| Wraithstep | Normal | 89% | 0.4 | 0.2 | 1.2 | 0.0 | 0.0 | 0.0 | 59 | 114 / 5 | 8/8 |
| Wraithstep | Hard | 96% | 0.1 | 0.2 | 4.6 | 0.0 | 0.0 | 0.0 | 20 | 114 / 1 | 8/8 |

## 5. Low health (bot starts at 25% vs spam)
| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | Easy | 19% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 20 / 36 | 0/16 |
| Bulwark | Normal | 31% | 0.1 | 0.0 | 0.2 | 0.0 | 0.0 | 0.0 | 33 | 28 / 35 | 1/16 |
| Bulwark | Hard | 16% | 0.3 | 0.0 | 0.4 | 0.0 | 0.0 | 0.0 | 21 | 14 / 36 | 0/16 |
| Tempest | Easy | 25% | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 22 / 31 | 1/16 |
| Tempest | Normal | 36% | 0.2 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0 | 48 / 28 | 3/16 |
| Tempest | Hard | 38% | 1.4 | 0.0 | 1.6 | 0.0 | 0.0 | 0.0 | 43 | 102 / 16 | 10/16 |
| Solarion | Easy | 20% | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 22 / 34 | 0/16 |
| Solarion | Normal | 36% | 0.6 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0 | 55 / 33 | 1/16 |
| Solarion | Hard | 39% | 0.8 | 0.1 | 1.3 | 0.0 | 0.0 | 0.0 | 18 | 58 / 31 | 2/16 |
| Wraithstep | Easy | 69% | 0.2 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 2 | 22 / 28 | 0/16 |
| Wraithstep | Normal | 66% | 0.4 | 0.0 | 0.6 | 0.0 | 0.0 | 0.0 | 70 | 54 / 23 | 4/16 |
| Wraithstep | Hard | 58% | 0.7 | 0.1 | 1.9 | 0.0 | 0.0 | 0.0 | 39 | 55 / 22 | 4/16 |

## Cost
BotAI.think: 5.6 microseconds per server tick on average (458373 ticks, this machine, plain Luau).
