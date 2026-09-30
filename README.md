# Truth Bias in Human Reinforcement Learning

This repository contains the behavioural data, fitted model parameters, simulation code, mixed-effects analyses, and plotting functions used to reproduce the main results of the paper **"Truth Bias in Human Reinforcement Learning"**.

The study tests whether outcome information labelled as truthful has a greater influence on reinforcement learning than equally informative information labelled as untruthful. Across two studies, the analyses examine truth bias in belief updating, its dependence on source certainty and environmental truth base rates, its relationship to explicit beliefs, and its effects on choice speed and accuracy.

## About the Paper

* **Authors:** Juan Vidal-Perez, Raymond J. Dolan, Rani Moran
* **Study 1:** N = 201
* **Study 2:** N = 202
* **Total sample:** N = 403

---

# Repository Structure

A recommended organization is:

```text
.
├── README.md
├── data/
│   ├── README.md
│   ├── data_s1.mat
│   ├── data_s2.mat
│   ├── <CA parameter file(s)>.mat
│   └── <CA-DDM parameter file>.mat
│
├── models/
│   ├── my_CAmodel_fitter.m
│   ├── simulation_CA.m
│   ├── simulation_CADDM.m
│   └── my_CADDMmodel_fitter.m
│
├── analyses/
│   ├── analyse_ModelAgnostic.m
│   ├── analyse_CA_parameters.m
│   ├── analyse_CADDM_parameters.m
│   ├── analyse_explicit_ratings.m
│   └── analyse_RTACC.m
│
└── plots/
    ├── plot_2by2.m
    ├── plot_swarm_summary.m
    ├── plot_FittedParameters_CA.m
    ├── plot_FittedParameters_CADDM.m
    └── plot_Figure4_ratings.m
```

For a detailed description of the behavioural variables and fitted parameter matrices, see [`data/README.md`](data/README.md).

---

# Requirements

The analysis code is written in MATLAB.

Required toolboxes:

* **Statistics and Machine Learning Toolbox**
  * `fitglme`
  * `fitlm`
  * `randsample`
* **Optimization Toolbox**
  * `fmincon`
* **Parallel Computing Toolbox** *(optional)*
  * used by `parfor` during model fitting;
  * replace `parfor` with `for` if unavailable.
* **bayesFactor MATLAB toolbox** *(only for the Bayes-factor analyses reported in the paper)*

The CA-DDM fitter contains the Wiener first-passage-time likelihood code used for fitting.

---

# Loading the Data

A safe way to load both studies without overwriting the variable `data` is:

```matlab
clear
clc

addpath(genpath(pwd))

load(fullfile('data','data.mat'));
```

Then load the fitted parameter files:

```matlab
load(fullfile('data','parameters_CAmodel.mat'))
load(fullfile('data','parameters_CADDMmodel.mat'))
```

Replace the placeholder filenames with the actual filenames used in the repository.

---

# Main Functions

## `my_CAmodel_fitter.m`

Fits the reinforcement-learning Credit Assignment (CA) models by maximum likelihood.

```matlab
[parameters, loglik] = my_CAmodel_fitter(data, model);
```

Models:

```matlab
'null'
'certainty'
'truth'
'truthxcertainty'
'truthxcertaintyxbr'   % Study 2 only
```

Each participant is fitted from 10 random starting points and the maximum-likelihood solution is retained.

---

## `simulation_CA.m`

Generates synthetic behavioural data from the CA models.

```matlab
[simulated_data, parameters_used] = ...
    simulation_CA(parameters, model, study, shuff);
```

where:

```text
study = 1 or 2
shuff = false or true
```

All models can be simulated in both study structures except:

```matlab
'truthxcertaintyxbr'
```

which is defined only for Study 2.

---

## `my_CADDMmodel_fitter.m`

Fits the Study 1 CA-DDM model to choices and reaction times.

```matlab
[parameters, loglik] = my_CADDMmodel_fitter(data_s1, model);
```

Models:

```matlab
'full'
'ablate_cv'
'ablate_t0'
```

---

## `CA-DDM Simulations and Ablation Analysis`

Generates synthetic behavioural data from the CA models.

This analysis is restricted to **Study 1**.

```matlab
[simulated_data, parameters_used] = ...
    simulation_CADDM(parameters, model, study, shuff);
```

where:

```text
study = 1 or 2
shuff = false or true
```



## `analyse_ModelAgnostic.m`

Runs the model-agnostic choice-repetition analysis.

```matlab
[mdl, out] = analyse_ModelAgnostic(data, study);
```

The function:

* calculates participant-level choice-repetition probabilities;
* recodes feedback into implied-feedback coordinates;
* computes the feedback effect on choice repetition;
* fits the mixed-effects binomial regression;
* generates the corresponding plots.

---

## `analyse_CA_parameters.m`

Fits the mixed-effects models reported for the fitted CA parameters.

Study 1:

```matlab
mdl_ca_s1 = analyse_CA_parameters( ...
    par_truthxcertainty_s1, 1);
```

Study 2:

```matlab
mdl_ca_s2 = analyse_CA_parameters( ...
    par_truthxcertaintyxbr_s2, 2);
```

Explicit truth bias moderation analysis:

```matlab
mdl_ca_explicit = analyse_CA_parameters( ...
    par_truthxcertainty_s2, ...
    2, ...
    'explicit_tb', ...
    data_s2);
```

---

## `analyse_CADDM_parameters.m`

Runs mixed-effects analyses on the fitted Study 1 CA-DDM parameters.

```matlab
mdl_cv = analyse_CADDM_parameters( ...
    par_full_s1, 'cv', 'main');

mdl_a = analyse_CADDM_parameters( ...
    par_full_s1, 'a', 'main');

mdl_t0 = analyse_CADDM_parameters( ...
    par_full_s1, 't0', 'main');
```

The certainty-inclusive SI analyses can be run with the `'full'` option where applicable.

---

## `analyse_explicit_ratings.m`

Runs the Study 2 mixed-effects analysis of explicit source ratings.

Main analysis:

```matlab
[mdl_explicit, ETP] = ...
    analyse_explicit_ratings(data_s2, 'main');
```

Preregistered valence-inclusive analysis:

```matlab
mdl_explicit_preregistered = ...
    analyse_explicit_ratings(data_s2, 'preregistered');
```

---

## `analyse_RTACC.m`

Computes source-specific reaction time and choice accuracy and fits the corresponding mixed-effects models.

Main analyses:

```matlab
[mdl_rt_s1, mdl_acc_s1, rtacc_s1] = ...
    analyse_RTACC(data_s1, 1, 'main');

[mdl_rt_s2, mdl_acc_s2, rtacc_s2] = ...
    analyse_RTACC(data_s2, 2, 'main');
```

Certainty-inclusive SI analyses:

```matlab
[mdl_rt_s1_full, mdl_acc_s1_full] = ...
    analyse_RTACC(data_s1, 1, 'full', false);

[mdl_rt_s2_full, mdl_acc_s2_full] = ...
    analyse_RTACC(data_s2, 2, 'full', false);
```

---

# Plotting Functions

## `plot_2by2.m`

Generic summary plot for the Truthfulness × Certainty design.

## `plot_swarm_summary.m`

Generic participant-level swarm/summary plotting helper.

## `plot_FittedParameters_CA.m`

Plots fitted CA parameters.

```matlab
plot_FittedParameters_CA( ...
    par_truthxcertainty_s1, ...
    'truthxcertainty');

plot_FittedParameters_CA( ...
    par_truthxcertaintyxbr_s2, ...
    'truthxcertaintyxbr');
```

## `plot_FittedParameters_CADDM.m`

Plots the fitted CA and DDM parameters from the full or ablated CA-DDM models.

```matlab
plot_FittedParameters_CADDM( ...
    par_full_s1, ...
    'full');
```

## `plot_Figure4_ratings.m`

Produces the explicit-rating plots used in Figure 4 and returns participant-level explicit and RL truth-bias measures.

```matlab
out_ratings = plot_Figure4_ratings( ...
    data_s2, ...
    par_truthxcertainty_s2);
```

---

# Reproducing the Main Figures and Results


## Figure 2: Learning Adaptations to Truthfulness and Certainty

### Figure 2a-b: Model-Agnostic Choice Repetition

```matlab
[mdl_rep_s1, rep_s1] = ...
    analyse_ModelAgnostic(data_s1, 1);
```

This reproduces the empirical choice-repetition analysis and the feedback-effect summary.


### Figure 2d: CA Parameters

```matlab
plot_FittedParameters_CA( ...
    par_truthxcertainty_s1, ...
    'truthxcertainty');

mdl_ca_s1 = analyse_CA_parameters( ...
    par_truthxcertainty_s1, ...
    1);
```


### Optional: Refit Study 1 CA Models

```matlab
[par_null_s1, loglik_null_s1] = ...
    my_CAmodel_fitter(data_s1,'null');

[par_certainty_s1, loglik_certainty_s1] = ...
    my_CAmodel_fitter(data_s1,'certainty');

[par_truth_s1, loglik_truth_s1] = ...
    my_CAmodel_fitter(data_s1,'truth');

[par_truthxcertainty_s1, loglik_truthxcertainty_s1] = ...
    my_CAmodel_fitter(data_s1,'truthxcertainty');
```

---

## Figure 3: Modulation by the Base Rate of Truth

### Figure 3b: Accuracy in TP vs LP Blocks

```matlab
[~, ~, rtacc_s2] = ...
    analyse_RTACC(data_s2, 2, 'main', false);

acc_TP = mean(rtacc_s2.acc(:,:,1),2,'omitnan');
acc_LP = mean(rtacc_s2.acc(:,:,2),2,'omitnan');
```

Plot:

```matlab
figure

plot_swarm_summary( ...
    [acc_TP acc_LP], ...
    [1 2], ...
    {'TP','LP'}, ...
    [44 99 197; 197 97 3]/255, ...
    'Condition', ...
    'Mean accuracy rate', ...
    false);
```

Paired comparison:

```matlab
[h,p,ci,stats] = ttest(acc_TP,acc_LP)
```

### Figure 3c: CA Parameters Across TP and LP

```matlab
plot_FittedParameters_CA( ...
    par_truthxcertaintyxbr_s2, ...
    'truthxcertaintyxbr');

mdl_ca_s2 = analyse_CA_parameters( ...
    par_truthxcertaintyxbr_s2, ...
    2);
```

### Figure 3d: Truth Bias Across TP and LP

```matlab
CA_TP = par_truthxcertaintyxbr_s2(:,1:4);
CA_LP = par_truthxcertaintyxbr_s2(:,5:8);

TB_TP = ...
    (CA_TP(:,3) + CA_TP(:,4) - CA_TP(:,2) - CA_TP(:,1)) / 2;

TB_LP = ...
    (CA_LP(:,3) + CA_LP(:,4) - CA_LP(:,2) - CA_LP(:,1)) / 2;
```

Plot:

```matlab
figure

plot_swarm_summary( ...
    [TB_TP TB_LP], ...
    [1 2], ...
    {'TP','LP'}, ...
    [44 99 197; 197 97 3]/255, ...
    'Condition', ...
    'Truth bias', ...
    true);
```

Bayesian paired comparison:

```matlab
[bf10] = bf.ttest(TB_TP,TB_LP)
```

The paper additionally reports a Bayes factor for this comparison.

### Optional: Refit Study 2 CA Models

```matlab
[par_null_s2, loglik_null_s2] = ...
    my_CAmodel_fitter(data_s2,'null');

[par_certainty_s2, loglik_certainty_s2] = ...
    my_CAmodel_fitter(data_s2,'certainty');

[par_truth_s2, loglik_truth_s2] = ...
    my_CAmodel_fitter(data_s2,'truth');

[par_truthxcertainty_s2, loglik_truthxcertainty_s2] = ...
    my_CAmodel_fitter(data_s2,'truthxcertainty');

[par_truthxcertaintyxbr_s2, loglik_truthxcertaintyxbr_s2] = ...
    my_CAmodel_fitter(data_s2,'truthxcertaintyxbr');
```

---

## Figure 4: Explicit Beliefs About Source Truthfulness

### Figure 4b-d

```matlab
out_ratings = plot_Figure4_ratings( ...
    data_s2, ...
    par_truthxcertainty_s2);
```

This produces:

* raw reward-probability ratings;
* Explicit Truth Probability (ETP);
* explicit truth bias;
* RL truth bias;
* the explicit-vs-RL truth-bias correlation.


### Explicit-Rating Mixed-Effects Model

```matlab
[mdl_explicit, ETP] = ...
    analyse_explicit_ratings( ...
        data_s2, ...
        'main');
```

The main model tests:

```text
ETP ~ TRUE * CERTAIN
```

Preregistered valence-inclusive model:

```matlab
mdl_explicit_preregistered = ...
    analyse_explicit_ratings( ...
        data_s2, ...
        'preregistered');
```


---

## Figure 5: Truth Asymmetries in Choice and Decision Processes

### Figure 5a-b: Reaction Time and Accuracy

```matlab
[mdl_rt_s1, mdl_acc_s1, rtacc_s1] = ...
    analyse_RTACC( ...
        data_s1, ...
        1, ...
        'main');

[mdl_rt_s2, mdl_acc_s2, rtacc_s2] = ...
    analyse_RTACC( ...
        data_s2, ...
        2, ...
        'main');
```

Main models:

```text
Study 1:
    RT       ~ TRUE
    ACCURACY ~ TRUE

Study 2:
    RT       ~ TRUE * BASE_RATE
    ACCURACY ~ TRUE * BASE_RATE
```

Certainty-inclusive SI models:

```matlab
[mdl_rt_s1_full, mdl_acc_s1_full] = ...
    analyse_RTACC(data_s1,1,'full',false);

[mdl_rt_s2_full, mdl_acc_s2_full] = ...
    analyse_RTACC(data_s2,2,'full',false);
```


### Figure 5d-f: CA-DDM Parameters

```matlab
plot_FittedParameters_CADDM( ...
    par_full_s1, ...
    'full');
```

Mixed-effects analyses:

```matlab
mdl_cv = analyse_CADDM_parameters( ...
    par_full_s1, ...
    'cv', ...
    'main');

mdl_a = analyse_CADDM_parameters( ...
    par_full_s1, ...
    'a', ...
    'main');

mdl_t0 = analyse_CADDM_parameters( ...
    par_full_s1, ...
    't0', ...
    'main');
```

CA parameters from the CA-DDM:

```matlab
mdl_caddm_ca = analyse_CADDM_parameters( ...
    par_full_s1, ...
    'CA', ...
    'full');
```

### Optional: Refit the CA-DDM

```matlab
[par_full_s1, loglik_full_s1] = ...
    my_CADDMmodel_fitter(data_s1,'full');

[par_ablatecv_s1, loglik_ablatecv_s1] = ...
    my_CADDMmodel_fitter(data_s1,'ablate_cv');

[par_ablatet0_s1, loglik_ablatet0_s1] = ...
    my_CADDMmodel_fitter(data_s1,'ablate_t0');
```

---

# Simulating the CA Models

Study 1:

```matlab
sim_s1 = simulation_CA( ...
    par_truthxcertainty_s1, ...
    'truthxcertainty', ...
    1, ...
    false);
```

Study 2:

```matlab
sim_s2 = simulation_CA( ...
    par_truthxcertaintyxbr_s2, ...
    'truthxcertaintyxbr', ...
    2, ...
    false);
```

The simulated output follows the same data structure as the empirical data and can therefore be passed to the same analysis functions:

```matlab
[mdl_sim, out_sim] = ...
    analyse_ModelAgnostic(sim_s1,1);
```


# Simulating the CA-DDM Models

The CA-DDM models are only used in **Study 1**.

Full model:

```matlab
sim_full = simulation_CADDM( ...
    par_full_s1, ...
    'full', ...
    false);
```

Ablated drift-scaling model:

```matlab
sim_ablatecv = simulation_CADDM( ...
    par_ablatecv_s1, ...
    'ablate_cv', ...
    false);
```

Ablated non-decision-time model:

```matlab
sim_ablatet0 = simulation_CADDM( ...
    par_ablatet0_s1, ...
    'ablate_t0', ...
    false);
```

The simulated output follows the same general data structure as the empirical Study 1 data and can therefore be passed to the same reaction-time and accuracy analyses:

```matlab
[mdl_rt_sim, mdl_acc_sim] = ...
    analyse_RTACC( ...
        sim_full, ...
        1, ...
        'main', ...
        false);
```

The same analysis can be applied to the ablated-model simulations:

```matlab
[mdl_rt_ablatecv, mdl_acc_ablatecv] = ...
    analyse_RTACC( ...
        sim_ablatecv, ...
        1, ...
        'main', ...
        false);

[mdl_rt_ablatet0, mdl_acc_ablatet0] = ...
    analyse_RTACC( ...
        sim_ablatet0, ...
        1, ...
        'main', ...
        false);
```# TruthBiasInHumanReinforcementLearning
