function out = plot_FittedParameters_CA(parameters, model)
% PLOT_FITTEDPARAMETERS_CA
%
% Plots fitted parameters from the Credit-Assignment (CA) models used in
% the manuscript.
%
% INPUTS
%   parameters - nParticipant x nParameter matrix returned by
%                my_CAmodel_fitter().
%
%   model      - Model name:
%
%                   'null'
%                   'certainty'
%                   'truth'
%                   'truthxcertainty'
%                   'truthxcertaintyxbr'
%
%                'truthxcertaintyxbr' is only defined for Study 2.
%
% OUTPUT
%   out        - Structure containing the quantities displayed:
%
%                   out.CA
%                       CA parameters for the non-base-rate models.
%
%                   out.CA_TP
%                   out.CA_LP
%                       CA parameters for Truth-Prevalent and
%                       Lie-Prevalent blocks in the base-rate model.
%
%                   out.other
%                       Remaining parameters: PERS, fQ, fP.
%
% NOTES
%   Feedback from 1- and 2-star sources is already sign-flipped during
%   model fitting. Therefore, fitted CA parameters are plotted directly
%   and must NOT be sign-flipped again here.


%% Plot settings

colors = [255 127   0;
          253 191 111;
          166 206 227;
           55 126 184] / 255;

source_labels = {'0','1/3','2/3','1'};


%% Plot fitted parameters

switch model

    % ====================================================================
    % Null model
    % ====================================================================
    case 'null'

        check_n_parameters(parameters, 4, model);

        out.CA = parameters(:,1);
        out.other = parameters(:,2:4);


        figure
        plot([0.5 1.5],[0 0],'--','Color',[0.3 0.3 0.3])
        hold on

        plot_swarm_summary( ...
            out.CA, ...
            1, ...
            {'CA'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Null model')


        figure

        plot_swarm_summary( ...
            out.other, ...
            1:3, ...
            {'PERS','f_Q','f_P'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Null model: other parameters')


    % ====================================================================
    % Certainty model
    % ====================================================================
    case 'certainty'

        check_n_parameters(parameters, 5, model);

        out.CA = parameters(:,1:2);
        out.other = parameters(:,3:5);

        certainty_colors = [ ...
            mean(colors([2 3],:),1);
            mean(colors([1 4],:),1)];


        figure
        plot([0.5 2.5],[0 0],'--','Color',[0.3 0.3 0.3])
        hold on

        plot_swarm_summary( ...
            out.CA, ...
            [1 2], ...
            {'Uncertain','Certain'}, ...
            certainty_colors, ...
            'Certainty level', ...
            'Credit assignment (CA)', ...
            true);

        title('Certainty model')


        figure

        plot_swarm_summary( ...
            out.other, ...
            1:3, ...
            {'PERS','f_Q','f_P'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Certainty model: other parameters')


    % ====================================================================
    % Truth model
    % ====================================================================
    case 'truth'

        check_n_parameters(parameters, 5, model);

        % Feedback is already flipped during fitting, so no sign change here
        out.CA = parameters(:,1:2);
        out.other = parameters(:,3:5);

        truth_colors = [ ...
            mean(colors(1:2,:),1);
            mean(colors(3:4,:),1)];


        figure
        plot([0.5 2.5],[0 0],'--','Color',[0.3 0.3 0.3])
        hold on

        plot_swarm_summary( ...
            out.CA, ...
            [1 2], ...
            {'Untruthful','Truthful'}, ...
            truth_colors, ...
            'Source truthfulness', ...
            'Credit assignment (CA)', ...
            true);

        title('Truth model')


        figure

        plot_swarm_summary( ...
            out.other, ...
            1:3, ...
            {'PERS','f_Q','f_P'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Truth model: other parameters')


    % ====================================================================
    % Truth x Certainty model
    % ====================================================================
    case 'truthxcertainty'

        check_n_parameters(parameters, 7, model);

        % Source-specific CA parameters are already in implied-feedback
        % coordinates after refitting / sign conversion.
        out.CA = parameters(:,1:4);
        out.other = parameters(:,5:7);


        % Source-specific CA parameters
        figure

        plot([0 5],[0 0],'--','Color',[0.3 0.3 0.3])
        hold on

        plot_swarm_summary( ...
            out.CA, ...
            1:4, ...
            source_labels, ...
            colors, ...
            'Source credibility', ...
            'Credit assignment (CA)', ...
            true);

        title('Truth x Certainty model')


        % 2 x 2 representation
        figure

        plot([0 3],[0 0],'k--')
        hold on

        plot_2by2( ...
            out.CA, ...
            [2.1 1.1 0.9 1.9], ...
            {'Uncertain','Certain'}, ...
            1, ...
            colors, ...
            'Credit assignment (CA)');

        xlabel('Certainty level')
        ylim([-1 3])


        % Other parameters
        figure

        plot_swarm_summary( ...
            out.other, ...
            1:3, ...
            {'PERS','f_Q','f_P'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Truth x Certainty model: other parameters')


    % ====================================================================
    % Truth x Certainty x Base Rate model
    % ====================================================================
    case 'truthxcertaintyxbr'

        check_n_parameters(parameters, 11, model);

        % Feedback is already sign-flipped during fitting
        out.CA_TP = parameters(:,1:4);
        out.CA_LP = parameters(:,5:8);
        out.other = parameters(:,9:11);


        % ---------------------------------------------------------------
        % Source-specific CA parameters across base-rate conditions
        % ---------------------------------------------------------------

        figure

        x = [1 2 3.5 4.5 6 7 8.5 9.5];

        CA_all = [ ...
            out.CA_TP(:,1), out.CA_LP(:,1), ...
            out.CA_TP(:,2), out.CA_LP(:,2), ...
            out.CA_TP(:,3), out.CA_LP(:,3), ...
            out.CA_TP(:,4), out.CA_LP(:,4)];

        plot([0 10.5],[0 0],'--','Color',[0.3 0.3 0.3])
        hold on

        for source = 1:4

            idx = 2*source + [-1 0];

            plot( ...
                x(idx), ...
                mean(CA_all(:,idx),1), ...
                '-', ...
                'LineWidth',2, ...
                'Color',colors(source,:));

            hold on
        end

        plot_swarm_summary( ...
            CA_all, ...
            x, ...
            {'TP','LP','TP','LP','TP','LP','TP','LP'}, ...
            repelem(colors,2,1), ...
            'Base-rate condition', ...
            'Credit assignment (CA)', ...
            true);

        title('Truth x Certainty x Base Rate model')


        % ---------------------------------------------------------------
        % 2 x 2 CA plots by base-rate condition
        % ---------------------------------------------------------------

        figure

        subplot(1,2,1)

        plot([0 3],[0 0],'k--')
        hold on

        plot_2by2( ...
            out.CA_TP, ...
            [2.1 1.1 0.9 1.9], ...
            {'Uncertain','Certain'}, ...
            1, ...
            colors, ...
            'Credit assignment (CA)');

        title('Truth-prevalent')
        ylim([-1 2])


        subplot(1,2,2)

        plot([0 3],[0 0],'k--')
        hold on

        plot_2by2( ...
            out.CA_LP, ...
            [2.1 1.1 0.9 1.9], ...
            {'Uncertain','Certain'}, ...
            1, ...
            colors, ...
            '');

        title('Lie-prevalent')
        ylim([-1 2])


        % ---------------------------------------------------------------
        % Other parameters
        % ---------------------------------------------------------------

        figure

        plot_swarm_summary( ...
            out.other, ...
            1:3, ...
            {'PERS','f_Q','f_P'}, ...
            [], ...
            'Parameter', ...
            'Fitted value', ...
            true);

        title('Truth x Certainty x Base Rate model: other parameters')


    otherwise
        error('Unknown model: %s', model)

end

end


%% ========================================================================
%  PARAMETER COUNT CHECK
%  ========================================================================
function check_n_parameters(parameters, expected, model)
% CHECK_N_PARAMETERS
%
% Checks that the supplied matrix has the expected number of parameters.

if size(parameters,2) ~= expected
    error( ...
        ['Model ''%s'' expects %d parameters, but the supplied matrix ' ...
         'contains %d columns.'], ...
        model, expected, size(parameters,2));
end

end