function out = plot_FittedParameters_CADDM(parameters, model)
% PLOT_FITTEDPARAMETERS_CADDM
%
% Plots fitted parameters from the Study 1 Credit-Assignment
% Drift-Diffusion Model (CA-DDM).
%
% INPUTS
%   parameters - nParticipant x nParameter matrix returned by
%                my_CADDMmodel_fitter().
%
%   model      - CA-DDM variant:
%
%                   'full'
%                       Source-specific cv, a, and t0.
%
%                   'ablate_cv'
%                       cv fixed to 1 for all sources.
%
%                   'ablate_t0'
%                       Shared t0 across sources.
%
% OUTPUT
%   out        - Structure containing unpacked parameters:
%
%                   out.CA      - source-specific CA parameters
%                   out.PERS    - perseveration
%                   out.fQ      - Q forgetting
%                   out.fP      - perseveration forgetting
%                   out.cv      - drift-rate scaling by source
%                   out.a       - boundary separation by source
%                   out.t0      - non-decision time by source
%
% NOTES
%   Feedback from 1-/2-star sources is already sign-flipped during model
%   fitting and represented as implied_feedback. Therefore CA parameters
%   are plotted directly and must NOT be sign-flipped here.
%
%   Source order:
%       1 = 1-star
%       2 = 2-star
%       3 = 3-star
%       4 = 4-star


%% Settings

colors = [255 127   0;
          253 191 111;
          166 206 227;
           55 126 184] / 255;

source_labels = {'0','1/3','2/3','1'};

truth_colors = [ ...
    mean(colors(1:2,:),1); ...
    mean(colors(3:4,:),1)];


%% Unpack parameters

out = unpack_CADDM_parameters(parameters, model);


%% ========================================================================
%  CREDIT ASSIGNMENT
%  ========================================================================

% Source-specific CA parameters
figure

plot([0.5 4.5],[0 0],'--','Color',[0.3 0.3 0.3])
hold on

plot_swarm_summary( ...
    out.CA, ...
    1:4, ...
    source_labels, ...
    colors, ...
    'Source credibility', ...
    'Credit assignment (CA)', ...
    true);

title('CA-DDM: credit assignment')


% 2 x 2 Truth x Certainty representation
figure

plot([0 3],[0 0],'k--')
hold on

plot_2by2( ...
    out.CA, ...
    [2.1 1.1 0.9 1.9], ...
    {'Uncertain','Certain'}, ...
    0, ...
    colors, ...
    'Credit assignment (CA)');

xlabel('Certainty level')


%% ========================================================================
%  DDM PARAMETERS: LYING VS TRUTHFUL SOURCES
%  ========================================================================
%
% These correspond to the summary quantities shown in the main-text
% CA-DDM figure.

cv_truth = [ ...
    mean(out.cv(:,1:2),2), ...
    mean(out.cv(:,3:4),2)];

a_truth = [ ...
    mean(out.a(:,1:2),2), ...
    mean(out.a(:,3:4),2)];

t0_truth = [ ...
    mean(out.t0(:,1:2),2), ...
    mean(out.t0(:,3:4),2)];


figure

subplot(1,3,1)

plot_swarm_summary( ...
    cv_truth, ...
    [1 2], ...
    {'Untruthful','Truthful'}, ...
    truth_colors, ...
    'Source truthfulness', ...
    'Average c_v', ...
    true);

subplot(1,3,2)

plot_swarm_summary( ...
    a_truth, ...
    [1 2], ...
    {'Untruthful','Truthful'}, ...
    truth_colors, ...
    'Source truthfulness', ...
    'Average a', ...
    true);

subplot(1,3,3)

plot_swarm_summary( ...
    t0_truth, ...
    [1 2], ...
    {'Untruthful','Truthful'}, ...
    truth_colors, ...
    'Source truthfulness', ...
    'Average t_0', ...
    true);


%% ========================================================================
%  SOURCE-SPECIFIC DDM PARAMETERS
%  ========================================================================
%
% Useful for the supplementary analyses showing Truth x Certainty effects.

figure

subplot(3,1,1)

plot_2by2( ...
    out.cv, ...
    [2.1 1.1 0.9 1.9], ...
    {'Uncertain','Certain'}, ...
    0, ...
    colors, ...
    'Drift-rate scaling (c_v)');

subplot(3,1,2)

plot_2by2( ...
    out.a, ...
    [2.1 1.1 0.9 1.9], ...
    {'Uncertain','Certain'}, ...
    0, ...
    colors, ...
    'Boundary separation (a)');

subplot(3,1,3)

plot_2by2( ...
    out.t0, ...
    [2.1 1.1 0.9 1.9], ...
    {'Uncertain','Certain'}, ...
    0, ...
    colors, ...
    'Non-decision time (t_0)');

xlabel('Certainty level')


%% Other RL parameters

figure

plot_swarm_summary( ...
    [out.PERS out.fQ out.fP], ...
    1:3, ...
    {'PERS','f_Q','f_P'}, ...
    [], ...
    'Parameter', ...
    'Fitted value', ...
    true);

title(sprintf('CA-DDM: %s', strrep(model,'_',' ')))

end


%% ========================================================================
%  PARAMETER UNPACKING
%  ========================================================================
function out = unpack_CADDM_parameters(parameters, model)
% UNPACK_CADDM_PARAMETERS
%
% Converts the fitted parameter matrix into consistently shaped quantities.
%
% All source-dependent parameters are returned as nParticipant x 4
% matrices, even when a parameter is fixed/shared in an ablated model.


switch model

    % ====================================================================
    % Full CA-DDM
    % ====================================================================
    case 'full'

        check_n_parameters(parameters,18,model);

        out.CA   = parameters(:,1:4);
        out.PERS = parameters(:,5);
        out.fQ   = parameters(:,6);
        out.fP   = parameters(:,7);

        % 1-star cv fixed to 1
        out.cv = [ ...
            ones(size(parameters,1),1), ...
            parameters(:,8:10)];

        out.a  = parameters(:,11:14);
        out.t0 = parameters(:,15:18);


    % ====================================================================
    % Ablate source-dependent drift scaling
    % ====================================================================
    case 'ablate_cv'

        check_n_parameters(parameters,15,model);

        out.CA   = parameters(:,1:4);
        out.PERS = parameters(:,5);
        out.fQ   = parameters(:,6);
        out.fP   = parameters(:,7);

        % cv fixed to 1 for all sources
        out.cv = ones(size(parameters,1),4);

        out.a  = parameters(:,8:11);
        out.t0 = parameters(:,12:15);


    % ====================================================================
    % Ablate source-dependent non-decision time
    % ====================================================================
    case 'ablate_t0'

        check_n_parameters(parameters,15,model);

        out.CA   = parameters(:,1:4);
        out.PERS = parameters(:,5);
        out.fQ   = parameters(:,6);
        out.fP   = parameters(:,7);

        % 1-star cv fixed to 1
        out.cv = [ ...
            ones(size(parameters,1),1), ...
            parameters(:,8:10)];

        out.a = parameters(:,11:14);

        % One shared t0
        out.t0 = repmat(parameters(:,15),1,4);


    otherwise
        error( ...
            'Unknown model ''%s''. Use full, ablate_cv, or ablate_t0.', ...
            model);

end

end


%% ========================================================================
%  PARAMETER COUNT CHECK
%  ========================================================================
function check_n_parameters(parameters, expected, model)
% CHECK_N_PARAMETERS
%
% Checks that the supplied parameter matrix matches the model.

if size(parameters,2) ~= expected

    error( ...
        ['Model ''%s'' expects %d parameters, but the supplied matrix ' ...
         'contains %d columns.'], ...
        model, expected, size(parameters,2));

end

end