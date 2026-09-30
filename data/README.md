# Data Organization and Variable Dictionary

This folder contains the behavioural data and fitted model parameters for **Truth Bias in Human Reinforcement Learning**.

The behavioural datasets are:

```text
data_s1.mat   Study 1, N = 201
data_s2.mat   Study 2, N = 202
```

The fitted CA and CA-DDM parameter files contain the maximum-likelihood parameter estimates used in the computational analyses.

---

# Behavioural Data Structure

The main behavioural variable in each dataset is a cell array called:

```matlab
data
```

with one row per participant and three columns:

```matlab
data{ss,1}   % participant identifier
data{ss,2}   % trials reordered by bandit pair / game
data{ss,3}   % trials in the actual task order
```

Thus:

```text
Study 1: 201 × 3 cell array
Study 2: 202 × 3 cell array
```

The two representations in columns 2 and 3 contain largely the same behavioural information, but organized differently for different analyses.

---

# `data{ss,1}`: Participant Identifier

```matlab
data{ss,1}
```

contains the participant identifier associated with row `ss`.

**The exact format of this identifier should be checked in the released MAT files before describing it as either a simple row index or an original participant ID.**

---

# `data{ss,3}`: Task-Order Data

```matlab
data{ss,3}
```

contains trials in the order in which they occurred during the experiment.

Each participant completed:

```text
8 blocks
3 bandit pairs per block
16 presentations per bandit pair
48 trials per block
384 trials in total
```

The main task-level fields are therefore generally stored as:

```text
8 × 48
```

matrices.

---

## `block`

```matlab
data{ss,3}.block
```

Block number:

```text
1, 2, ..., 8
```

---

## `trial`

```matlab
data{ss,3}.trial
```

Trial number within the current block:

```text
1, 2, ..., 48
```

---

## `agent`

```matlab
data{ss,3}.agent
```

Identity of the feedback source presented on the current trial:

```text
1 = 1-star source
2 = 2-star source
3 = 3-star source
4 = 4-star source
```


---

## `cred`

```matlab
data{ss,3}.cred
```

Numerical source credibility:

```text
0     = 1-star source
1/3   = 2-star source
2/3   = 3-star source
1     = 4-star source
```

Thus `agent` and `cred` encode the same source identity in categorical and numerical form.

---

## `pick`

```matlab
data{ss,3}.pick
```

Participant choice:

```text
1 = bandit 1
2 = bandit 2
0 = no valid choice / timeout
```

---

## `accuracy`

```matlab
data{ss,3}.accuracy
```

Whether the participant selected the objectively better bandit within the pair:

```text
0 = worse bandit chosen
1 = better bandit chosen
```

The two bandits within each pair have reward probabilities:

```text
bandit 1: P(reward) = 0.25
bandit 2: P(reward) = 0.75
```


---

## `reward`

```matlab
data{ss,3}.reward
```

True latent outcome of the chosen bandit:

```text
0 = non-reward
1 = reward
```

This outcome is latent during the task: participants do not directly observe it.

---

## `feedback`

```matlab
data{ss,3}.feedback
```

Literal outcome reported by the feedback source:

```text
0 = source reports non-reward
1 = source reports reward
```

This field contains the source's actual report and is **not** pre-flipped for mostly-lying sources.




## `game`

```matlab
data{ss,3}.game
```

Global identifier of the current bandit pair across the experiment.

Because there are three new pairs in each of eight blocks:

```text
1, 2, ..., 24
```

identify the 24 bandit pairs.

For model fitting, this is mapped back to the within-block pair index:

```matlab
game = mod(data.game' - 1,3) + 1;
```

giving:

```text
1, 2, or 3
```

---

## `response_time`

```matlab
data{ss,3}.response_time
```

Choice reaction time in milliseconds.



---

## `timeouts`

```matlab
data{ss,3}.timeouts
```

Indicator of whether a valid choice was made.

The simulation code uses:

```text
0 = valid response
1 = timeout
```


---

## `left`

```matlab
data{ss,3}.left
```

Binary variable representing whether the selected bandit was shown in the left or right of the screen.

The simulation code uses:

```text
0 = timeout/invalid response
1 = right
2 = left
```

---

# Study 2 Additional Variables

Study 2 has the same basic task structure plus an environmental source-prevalence manipulation.

---

## `condition`

```matlab
data{ss,3}.condition
```

Base-rate condition:

```text
1 = Truth-Prevalent (TP)
2 = Lie-Prevalent   (LP)
```

Source occurrence probabilities are:

| Condition | 1-star | 2-star | 3-star | 4-star |
|---|---:|---:|---:|---:|
| TP | 0.125 | 0.125 | 0.375 | 0.375 |
| LP | 0.375 | 0.375 | 0.125 | 0.125 |

In the mixed-effects models:

```text
TP = +0.5
LP = -0.5
```

---

# Study 2 Explicit Ratings

Study 2 additionally contains:

```matlab
data{ss,3}.ratings
```

a:

```text
4 × 2
```

matrix.

Rows correspond to sources:

```text
row 1 = 1-star
row 2 = 2-star
row 3 = 3-star
row 4 = 4-star
```

Columns correspond to the source feedback shown in the explicit-rating task:

```text
column 1 = non-reward feedback
column 2 = reward feedback
```

Each entry ranges from:

```text
0 to 100
```

and represents the participant's reported probability that the true latent outcome was a reward.

The explicit-rating analysis transforms these reports into **Explicit Truth Probability (ETP)**, i.e. the probability that the source-implied outcome is true.

For each source, the analysis:

1. converts the non-reward rating to the probability that non-reward was truly obtained;
2. flips the 1-star and 2-star ratings into implied-feedback coordinates;
3. averages across positive and negative feedback.

---

# `data{ss,2}`: Bandit-Pair-Ordered Data

```matlab
data{ss,2}
```

contains the same behaviour reorganized so repeated presentations of the same bandit pair occur along the same row.

There are:

```text
8 blocks × 3 bandit pairs = 24 rows
16 presentations per bandit pair
```

so the main fields are generally:

```text
24 × 16
```

matrices.

This representation is useful for analyses requiring the sequence of choices within the same bandit pair, such as choice repetition.

---

## `condition` — Study 2 only

```text
1 = Truth-Prevalent
2 = Lie-Prevalent
```



# Fitted CA Parameters

The retained CA model family is:

```text
null
certainty
truth
truthxcertainty
truthxcertaintyxbr
```

The base-rate model is used only for Study 2.

---

## Study 1

```matlab
par_null_s1                 % 201 × 4
par_certainty_s1            % 201 × 5
par_truth_s1                % 201 × 5
par_truthxcertainty_s1      % 201 × 7

loglik_null_s1              % 1 × 201
loglik_certainty_s1         % 1 × 201
loglik_truth_s1             % 1 × 201
loglik_truthxcertainty_s1   % 1 × 201
```

---

## Study 2

```matlab
par_null_s2                       % 202 × 4
par_certainty_s2                  % 202 × 5
par_truth_s2                      % 202 × 5
par_truthxcertainty_s2            % 202 × 7
par_truthxcertaintyxbr_s2         % 202 × 11

loglik_null_s2                    % 1 × 202
loglik_certainty_s2               % 1 × 202
loglik_truth_s2                   % 1 × 202
loglik_truthxcertainty_s2         % 1 × 202
loglik_truthxcertaintyxbr_s2      % 1 × 202
```

---

# CA Parameter Layouts

## `null`

```text
1  CA
2  PERS
3  fQ
4  fP
```

---

## `certainty`

```text
1  CA_uncertain
2  CA_certain
3  PERS
4  fQ
5  fP
```

---

## `truth`

```text
1  CA_untruthful
2  CA_truthful
3  PERS
4  fQ
5  fP
```

---

## `truthxcertainty`

```text
1  CA_1star
2  CA_2star
3  CA_3star
4  CA_4star
5  PERS
6  fQ
7  fP
```

---

## `truthxcertaintyxbr`

```text
1   CA_1star_TP
2   CA_2star_TP
3   CA_3star_TP
4   CA_4star_TP

5   CA_1star_LP
6   CA_2star_LP
7   CA_3star_LP
8   CA_4star_LP

9   PERS
10  fQ
11  fP
```

All final source-specific CA values are stored in **implied-feedback coordinates**.

---

# Fitted CA-DDM Parameters

The CA-DDM is fitted only in Study 1.

Saved variables:

```matlab
par_full_s1          % 201 × 18
par_ablatecv_s1      % 201 × 15
par_ablatet0_s1      % 201 × 15

loglik_full_s1       % 1 × 201
loglik_ablatecv_s1   % 1 × 201
loglik_ablatet0_s1   % 1 × 201
```

---

## `par_full_s1`

```text
1:4     source-specific CA
5       PERS
6       fQ
7       fP
8:10    free source-specific drift scaling cv for 2-/3-/4-star
11:14   source-specific boundary separation a
15:18   source-specific non-decision time t0
```

The 1-star `cv` is fixed to:

```text
1
```

for identifiability.

---

## `par_ablatecv_s1`

```text
1:4     source-specific CA
5       PERS
6       fQ
7       fP
8:11    source-specific a
12:15   source-specific t0
```

with:

```text
cv = 1
```

for all four sources.

---

## `par_ablatet0_s1`

```text
1:4     source-specific CA
5       PERS
6       fQ
7       fP
8:10    free cv for 2-/3-/4-star
11:14   source-specific a
15      shared t0
```

The 1-star `cv` is fixed to 1.

All CA parameters are stored using the final implied-feedback convention.

