function mdl = analyse_CADDM_parameters(parameters, parameter, analysis)
% ANALYSE_CADDM_PARAMETERS
%
% Fits mixed-effects models reported for the Study 1 CA-DDM parameters.
%
% INPUTS
%   parameters - par_full_s1 [N x 18].
%
%   parameter  - Parameter to analyse:
%
%                   'CA'
%                   'cv'
%                   'a'
%                   't0'
%
%   analysis   - Model specification:
%
%                   'main'   - Main-text analysis
%                   'full'   - Full Truth x Certainty SI analysis
%
% OUTPUT
%   mdl        - Fitted linear mixed-effects model.
%
% PARAMETER LAYOUT
%   1:4    CA
%   5      PERS
%   6      fQ
%   7      fP
%   8:10   free cv parameters for 2-/3-/4-star sources
%           (1-star cv fixed to 1)
%   11:14  boundary separation a
%   15:18  non-decision time t0
%
% NOTES
%   CA parameters are already expressed in implied-feedback coordinates.


if nargin < 3
    analysis = 'main';
end

if size(parameters,2) ~= 18
    error('The full CA-DDM model requires an N x 18 parameter matrix.')
end


switch parameter

    %% ===================================================================
    %  CREDIT ASSIGNMENT
    %  ===================================================================
    case 'CA'

        Y = parameters(:,1:4);

        [Y, TRUE, CERTAIN, SS] = ...
            expand_four_sources(Y);

        tbl = table( ...
            Y, TRUE, CERTAIN, SS, ...
            'VariableNames', ...
            {'CA','TRUE','CERTAIN','SS'});

        % CA is reported in the SI with Truth x Certainty
        mdl = fitglme( ...
            tbl, ...
            'CA ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)', ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


    %% ===================================================================
    %  DRIFT-RATE SCALING
    %  ===================================================================
        %% ===================================================================
    %  DRIFT-RATE SCALING
    %  ===================================================================
    case 'cv'

        % 1-star cv is fixed to 1.
        %
        % Analyse the three free parameters (2-/3-/4-star sources) as
        % deviations from the fixed 1-star reference.
        Y = parameters(:,8:10) - 1;

        nSub = size(Y,1);

        Y = Y';

        % Free parameters correspond to:
        %
        %   baseline  = 2-star
        %   SOURCE3   = 3-star vs 2-star
        %   SOURCE4   = 4-star vs 2-star
        SOURCE3 = repmat([0 1 0],1,nSub)';
        SOURCE4 = repmat([0 0 1],1,nSub)';

        SS = repelem((1:nSub)',3);

        tbl = table( ...
            Y(:), SOURCE3, SOURCE4, SS, ...
            'VariableNames', ...
            {'CV','SOURCE3','SOURCE4','SS'});

        mdl = fitglme( ...
            tbl, ...
            'CV ~ SOURCE3 + SOURCE4 + (SOURCE3 + SOURCE4 + 1|SS)', ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


        %% ---------------------------------------------------------------
        %  CONTRAST TESTS: TRUTH AND CERTAINTY
        %  ---------------------------------------------------------------
        %
        % Fixed-effect coefficient order:
        %   [Intercept, SOURCE3, SOURCE4]
        %
        % These contrasts reconstruct the factorial effects of source
        % truthfulness and certainty while accounting for the fact that
        % the 1-star cv parameter is fixed at 1.

        contrast_truth = [0.5 0.5 0.5];

        contrast_certainty = [-0.5 -0.5 0.5];


        % Truth effect
        [p_truth, F_truth, df1_truth, df2_truth] = ...
            coefTest(mdl, contrast_truth, 0);

        b_truth = ...
            contrast_truth * mdl.Coefficients.Estimate;


        % Certainty effect
        [p_certainty, F_certainty, df1_certainty, df2_certainty] = ...
            coefTest(mdl, contrast_certainty, 0);

        b_certainty = ...
            contrast_certainty * mdl.Coefficients.Estimate;


        %% Print contrast results

        fprintf('\nCA-DDM drift-scaling contrasts\n')
        fprintf('--------------------------------\n')

        fprintf( ...
            'Truth effect:     b = %.3f, F(%d, %.0f) = %.2f, p = %s\n', ...
            b_truth, ...
            df1_truth, ...
            df2_truth, ...
            F_truth, ...
            format_p(p_truth));

        fprintf( ...
            'Certainty effect: b = %.3f, F(%d, %.0f) = %.2f, p = %s\n\n', ...
            b_certainty, ...
            df1_certainty, ...
            df2_certainty, ...
            F_certainty, ...
            format_p(p_certainty));


    %% ===================================================================
    %  BOUNDARY SEPARATION
    %  ===================================================================
    case 'a'

        Y = parameters(:,11:14);

        [Y, TRUE, CERTAIN, SS] = ...
            expand_four_sources(Y);

        tbl = table( ...
            Y, TRUE, CERTAIN, SS, ...
            'VariableNames', ...
            {'A','TRUE','CERTAIN','SS'});

        switch analysis

            case 'main'
                formula = ...
                    'A ~ TRUE + (TRUE + 1|SS)';

            case 'full'
                formula = ...
                    'A ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)';

            otherwise
                error('analysis must be ''main'' or ''full''.')
        end

        mdl = fitglme( ...
            tbl, formula, ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


    %% ===================================================================
    %  NON-DECISION TIME
    %  ===================================================================
    case 't0'

        Y = parameters(:,15:18);

        [Y, TRUE, CERTAIN, SS] = ...
            expand_four_sources(Y);

        tbl = table( ...
            Y, TRUE, CERTAIN, SS, ...
            'VariableNames', ...
            {'T0','TRUE','CERTAIN','SS'});

        switch analysis

            case 'main'
                formula = ...
                    'T0 ~ TRUE + (TRUE + 1|SS)';

            case 'full'
                formula = ...
                    'T0 ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)';

            otherwise
                error('analysis must be ''main'' or ''full''.')
        end

        mdl = fitglme( ...
            tbl, formula, ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


    otherwise
        error('Unknown parameter: %s', parameter)

end

end


%% ========================================================================
%  FOUR-SOURCE DATA PREPARATION
%  ========================================================================
function [Y, TRUE, CERTAIN, SS] = expand_four_sources(Y)

nSub = size(Y,1);

Y = Y';

TRUE = repmat( ...
    [0 0 1 1], ...
    1,nSub)' - 0.5;

CERTAIN = repmat( ...
    [1 0 0 1], ...
    1,nSub)' - 0.5;

SS = repelem((1:nSub)',4);

Y = Y(:);

end

%% ========================================================================
%  P-VALUE FORMATTING
%  ========================================================================
function txt = format_p(p)

if p < 0.001
    txt = '< .001';
else
    txt = sprintf('%.3f',p);
end

end