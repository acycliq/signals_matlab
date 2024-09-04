function s = mergeStruct(dst, src)
%MERGESTRUCT Combines two structures into one scalar structure
%   s = MERGESTRUCTS(struct1, struct2)
%
%   If there are any repeated fields, the values from the second input are
%   used.
%

srcfields = fieldnames(src);
dstfields = fieldnames(dst);

if numel(srcfields) > 0.5*numel(dstfields)
  % merge by struct2cell -> cell2struct
  fields = [srcfields;dstfields];
  [uniqueFields, iFields] = unique(fields, 'stable');
  
  data = [struct2cell(src); struct2cell(dst)];
  
  mergedData = data(iFields);
  s = cell2struct(mergedData, uniqueFields, 1);
else % merge by directly updating the destination
  s = dst;
  for ii = 1:numel(srcfields)
    s.(srcfields{ii}) = src.(srcfields{ii});
  end
end


end

