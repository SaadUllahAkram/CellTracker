function delete(opts)

keep_fields = {'props','diary'};
for k=1:2
    if k == 1
        ss='tr';
    else
        ss='tt';
    end
if opts.redo_props
    for s=0:2
        del(opts.file.props(ss, s))
    end
end

if opts.redo
    fields = fieldnames(opts.file);
    for i=1:length(fields)
        if ~ismember(fields{i},keep_fields)
            for s=0:2
                del(opts.file.(fields{i})(ss, s))
            end
        end
    end
    fields = fieldnames(opts.fun);
    for i=1:length(fields)
        if ~ismember(fields{i},keep_fields)
            for s=0:2
                del(opts.fun.(fields{i})(ss, s))
            end
        end
    end
end
end

end


function del(file)
if exist(file, 'file')
    delete(file)
end
end