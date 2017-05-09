function pack(mode, opts, s)
% mode: 1: pack models, 2: unpack models
% s: train_seq

if length(s) > 1;   s = 0;  end

file_move = opts.fun.move_model(opts.train_str{2}, s);
file_mitosis = opts.fun.mitosis_model(opts.train_str{2}, s);
file_enter = opts.fun.enter_model(opts.train_str{2}, s);
file_exit = opts.fun.exit_model(opts.train_str{2}, s);

file_packed = opts.fun.packed(opts.train_str{2}, s);
if mode == 1
    mdl = struct();
    if opts.use_move
        move = load(file_move);
        mdl.mdl_move = move.mdl;
    end
    if opts.use_mitosis
        mitosis = load(file_mitosis);
        mdl.mdl_mitosis = mitosis.mdl;
    end
    if opts.use_enter
        enter = load(file_enter);
        mdl.mdl_enter = enter.mdl;
    end
    if opts.use_exit
        exit = load(file_exit);
        mdl.mdl_exit = exit.mdl;
    end
    save(file_packed, 'mdl')
    
    if exist(file_move, 'file')
        delete(file_move)
    end
    if exist(file_mitosis, 'file')
        delete(file_mitosis)
    end
    if exist(file_enter, 'file')
        delete(file_enter)
    end
    if exist(file_exit, 'file')
        delete(file_exit)
    end
else
    if ~exist(file_packed, 'file')
        return
    end
    load(file_packed, 'mdl')
    mdl_loc = mdl;
    
    if isfield(mdl_loc, 'mdl_move')
        mdl = mdl_loc.mdl_move;
        save(file_move, 'mdl')
    end
    
    if isfield(mdl_loc, 'mdl_mitosis')
        mdl = mdl_loc.mdl_mitosis;
        save(file_mitosis, 'mdl')
    end
    
    if isfield(mdl_loc, 'mdl_enter')
        mdl = mdl_loc.mdl_enter;
        save(file_enter, 'mdl')
    end
    
    if isfield(mdl_loc, 'mdl_exit')
        mdl = mdl_loc.mdl_exit;
        save(file_exit, 'mdl')
    end
end

end