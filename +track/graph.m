function graphs = graph(opts, data)
% ToDo:
% function which shows the prob. of connected cells in next frame. Show the union rect of all cells. Show GT cell labels

opts_default = struct('type_move',1,'type_prop',1,'type_enter',1,'type_exit',1,...
    'verbose',0,...
    'w', struct('prop',1,'move',1,'enter',1,'exit',1,'apoptosis',1,'mitosis',1),...
    'o',struct('prop',0,'move',0,'enter',0,'exit',0,'apoptosis',0,'mitosis',0),...
    'mitosis_pairs',1);
opts = bia.utils.updatefields(opts_default, opts);

verbose = opts.verbose;
w = opts.w;
o = opts.o;
modules = struct('mitosis',opts.use_mitosis,'apoptosis',opts.use_apoptosis,'move',opts.use_move,'enter',opts.use_enter,'exit',opts.use_exit);
% Read input data
T = data.gt.T;

p_cell = add_p_cell(data.stats);
time = p_cell(:,1);
p_cell = p_cell(:,3);% [t id prob.]

edges_move  = data.edges_move;% [id1 id2 p]
edges_enter = data.edges_enter; % [0,id,p], 0 is the entry/exit node
edges_exit  = data.edges_exit; % [id,0,p,t]

if opts.verbose;    fprintf('Move ratio: %1.4f\n', size(edges_move, 1)/length(p_cell));    end

if modules.mitosis && isfield(data, 'edges_mitosis');    mit_edges = data.edges_mitosis(:,[1:5]); %[id_par id_dau1 id_dau2 mitosis_pair_# prob]
else;   modules.mitosis = 0; mit_edges = zeros(0,5);
end
if modules.apoptosis && isfield(data, 'edges_apoptosis');    edges_apop = data.edges_apoptosis(:,1:3);% [t id prob.]
else;   modules.apoptosis = 0; edges_apop = zeros(0,3);
end

p_move = edges_move(:,3);

if strcmp(opts.score_transform, 'sq');    p_cell = p_cell.^2;
elseif strcmp(opts.score_transform, 'sqrt');    p_cell = sqrt(p_cell);
elseif strcmp(opts.score_transform, 'same');    p_cell = 0.5*ones(size(p_cell));
end

cost_cell = o.prop + w.prop*prob2cost(p_cell);
cost_move = o.move + w.move*prob2cost(p_move);
% enter
cost_enter = o.enter + w.enter*prob2cost(edges_enter(:,3)).*(time~=1);% use enter classifier prob.
% exit
cost_exit = o.exit + w.exit*prob2cost(edges_exit(:,3)).*(time~=T);% cost from classifier

% cell mitosis.
cost_mit = o.mitosis + w.mitosis*prob2cost(mit_edges(:,5));
% cell apoptosis
cost_apoptosis = o.apoptosis + w.apoptosis*prob2cost(edges_apop(:,3));

%% Tracking Graph (Proposals)
edges_move(:,3) = cost_move;
edges_exit(:,3) = cost_exit;
edges_enter(:,3)= cost_enter;
edges_apop(:,3) = cost_apoptosis;
edges_mitosis   = [mit_edges(:,[1 2]), cost_mit, mit_edges(:,[1 3]), cost_mit, mit_edges(:,4)];
prop_nodes      = cost_cell;
graph = struct('prop_nodes',prop_nodes,'edges_move',edges_move,'edges_exit',edges_exit,'edges_enter',edges_enter,...
    'edges_mitosis',edges_mitosis,'edges_apop',edges_apop,'constraints',{data.constraints},'conflicts',{data.conflicts},'w',{data.weights});
graphs = struct('graph', graph);

% Shortest Path Graph
if strcmp(opts.solver, 'sp')
    [~, map] = bia.convert.id(data.stats);
    graphs.graph_sp = track.sp.graph(graph, map, modules, verbose);
end
% ILP Graph
if strcmp(opts.solver, 'ilp')
    graphs.graph_ilp = track.ilp.graph(graph);
end

end


function c = prob2cost(p)
% converts prob. to cost, cost is in range ~[-37 37]
p(p>=1) = 1-eps;
p(p<=0) = eps;
c = -log(p./(1-p));
end


function p_cell = add_p_cell(stats)
p_cell = cell2mat(arrayfun(@(x,t) cell2mat(arrayfun(@(y) double([t{1} 0 y.Score]), x{1}, 'UniformOutput', false)), ...
    stats, num2cell(1:length(stats))', 'UniformOutput', false));
p_cell(:,2) = 1:size(p_cell,1);
end