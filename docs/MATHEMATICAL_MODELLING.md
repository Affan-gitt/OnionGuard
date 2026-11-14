# ONIONGUARD — MATHEMATICAL MODELLING & STORAGE RISK ANALYSIS

## 1. Principles of Post-Harvest Onion Preservation

Onions (*Allium cepa*) undergo dormancy following post-harvest field curing. Spoilage occurs primarily through three interacting physiological and microbial mechanisms:
1. **Thermal Stress & Respiration:** Temperatures above 24°C break dormancy, accelerating metabolic respiration, sugar depletion, and sprouting.
2. **Moisture & Microbial Proliferation:** Relative humidity exceeding 70% softens the dry protective outer scale and activates dormant fungal spores (*Aspergillus niger*, *Botrytis allii* neck rot, and *Erwinia carotovora* bacterial soft rot).
3. **Volatile Gas Accumulation:** Decaying tissue produces volatile organic compounds (VOCs) and anaerobic fermentation by-products (alcohols, esters) which can be qualitatively sensed by gas proxies.

---

## 2. Mathematical Formulations

### Model A: Temperature Deviation
$$\Delta T = T_{current} - T_{target}$$
Where $T_{target} = 20.0^\circ\text{C}$ (Standard storage target).

### Model B: Relative Humidity Deviation
$$\Delta H = H_{current} - H_{target}$$
Where $H_{target} = 65.0\%$ (Optimal storage range: 60% – 70% RH).

### Model C: Normalized Component Risk Functions ($0 - 100$)

1. **Temperature Risk ($R_{temp}$):**
   - For $15.0^\circ\text{C} \le T \le 22.0^\circ\text{C}$:
     $$R_{temp} = |T - 20.0| \times 3.0$$
   - For $T > 22.0^\circ\text{C}$:
     $$R_{temp} = \min(100.0, 15.0 + (T - 22.0) \times 6.5)$$
   - For $T < 15.0^\circ\text{C}$ (chilling injury risk):
     $$R_{temp} = \min(100.0, (15.0 - T) \times 5.0)$$

2. **Humidity Risk ($R_{humidity}$):**
   - For $60.0\% \le H \le 70.0\%$:
     $$R_{humidity} = |H - 65.0| \times 2.0$$
   - For $H > 70.0\%$ (mould / soft rot proliferation):
     $$R_{humidity} = \min(100.0, 20.0 + (H - 70.0) \times 5.5)$$
   - For $H < 60.0\%$ (bulb desiccation and weight loss):
     $$R_{humidity} = \min(100.0, (60.0 - H) \times 3.5)$$

3. **Gas Proxy Response Risk ($R_{gas}$):**
   Given relative shift from baseline:
   $$\Delta ADC\% = \frac{ADC_{raw} - ADC_{base}}{ADC_{base}} \times 100$$
   - For $\Delta ADC\% \le 5\%$: $R_{gas} = \Delta ADC\% \times 2.0$
   - For $5\% < \Delta ADC\% \le 25\%$: $R_{gas} = 10.0 + (\Delta ADC\% - 5.0) \times 1.5$
   - For $\Delta ADC\% > 25\%$: $R_{gas} = \min(100.0, 40.0 + (\Delta ADC\% - 25.0) \times 2.0)$

4. **Ventilation Risk ($R_{vent}$):**
   - If $T \ge T_{trigger}$ and exhaust fan is OFF: $R_{vent} = 85.0$ (Thermal stagnation)
   - If exhaust fan is actively running: $R_{vent} = 15.0$ (Active air exchange)
   - If $H \ge H_{safety}$: $R_{vent} = 60.0$ (High moisture stagnation)
   - Baseline nominal: $R_{vent} = 10.0$

### Model D: Composite Environmental Risk Index ($0 - 100$)
$$Risk = (W_t \times R_{temp}) + (W_h \times R_{humidity}) + (W_g \times R_{gas}) + (W_v \times R_{vent})$$

**Constraint:**
$$W_t + W_h + W_g + W_v = 1.0$$
- Default Weights: $W_t = 0.35$, $W_h = 0.30$, $W_g = 0.20$, $W_v = 0.15$.

### Model E: Health Classifications

| Risk Score Range | Classification | Storage Condition Status | Recommended Operator Action |
|---|---|---|---|
| **0 – 24** | **Good / Optimal** | Optimal preservation state | Maintain routine monitoring. |
| **25 – 49** | **Attention Required** | Mild environmental deviation | Inspect air pathways and monitor temperature trend. |
| **50 – 74** | **High Risk** | Elevated thermal or moisture stress | Verify exhaust operation; check shelves for soft bulbs. |
| **75 – 100** | **Critical Spoilage Danger** | Severe conditions favoring decay | Check racks immediately; quarantine rotting bulbs. |

---

## 3. Conceptual Spoilage Progression Estimator
Cumulative thermal-moisture stress index across storage duration:
$$StressIndex(t) = (t \times 0.15) + [\max(0, T_{avg} - 20) \times 0.08 \times t] + [\max(0, H_{avg} - 68) \times 0.10 \times t]$$
Where $t$ is storage duration in days.

---

## 4. Scientific Disclaimers & Sensor Limitations
1. **MQ-3 Is An Alcohol Sensor:** The MQ-3 metal oxide semiconductor sensor responds to ethanol, alcohol, and volatile combustible gases. It does NOT quantitatively measure ethylene ($C_2H_4$) concentration.
2. **Qualitative Engineering Proxy:** Readings from the MQ-3 are labeled and processed strictly as qualitative volatile decay proxies.
3. **Humidifier Is NOT An Ethylene Scrubber:** The demonstration actuator is a physical demonstration of a gas-triggered mechanism. A commercial storage unit utilizes potassium permanganate ($KMnO_4$) filtration beads.
