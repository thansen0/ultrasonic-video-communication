% mexOpenCV detectORBFeatures.cpp

disp('Starting');

im = imread('lower_res.png');
im = uint8(im);
im = rgb2gray(im);
[m, n] = size(im);

% Create value map
% 1269 is for 15fps, .19% of pixels
tic
value_map = generate_partitioned_peper(m, n, 9517);
toc

% create salt map from image using sobel edge detection
image_salt_map = edge(im);

% comparing image pepper map with value maps
tic
ssim_comparison = ssim(image_salt_map, value_map);
toc
disp('SSIM value')
disp(ssim_comparison);

quit; % exit

% values I would send, but in this case we're just leaving them in the
% vector
compressed_map = generate_compressed_image(value_map, im);
imshow(compressed_map);

tic
% now we want to rebuild the image from the compressed map, 
[reconstructed_map_1, new_value_map_1] = reconstruct_image(compressed_map, value_map, 11);
disp('first computed')
toc
% repeat with new values
[reconstructed_map_2, new_value_map_2] = reconstruct_image(reconstructed_map_1, new_value_map_1, 19);
disp('second computed')
toc
% repeat with new values
[reconstructed_map_3, new_value_map_3] = reconstruct_image(reconstructed_map_2, new_value_map_2, 21);
disp('third computed')
toc
% % repeat with new values
% [reconstructed_map_3, new_value_map_3] = reconstruct_image(reconstructed_map_3, new_value_map_3, 23);
% disp('fourth computed')
% toc
% % repeat with new values
% [reconstructed_map_3, new_value_map_3] = reconstruct_image(reconstructed_map_3, new_value_map_3, 23);
% disp('fifth computed')
% toc

figure()
imshowpair(im, reconstructed_map_3,'montage');
title('Original im and final reconstructed')

figure()
imshowpair(reconstructed_map_1, reconstructed_map_2,'montage');
title('reconstructed 1 and 2')

% This function takes in the compressed image and the value map and spits
% out a reconstructed map by convolving the image and calculating the mean
% square
function [reconstructed_map,new_value_map] = reconstruct_image(compressed_map, value_map, kernel)
    if (mod((kernel - 1),2) ~= 0)
        disp('kernel must be an odd numer'); % also must be >= 3
        return;
    end

    new_value_map = value_map; % will include new values to repeat
    reconstructed_map = compressed_map; % 
    
    [mr, nr] = size(value_map);
    k = (kernel - 1) / 2;
    
    for mc = 1:mr
        for nc = 1:nr
            if (value_map(mc,nc) == 0)
                % missing data in compressed_map
                mc_b = mc - k;
                if (mc_b <= 0)
                    mc_b = 1;
                end
                
                mc_t = mc + k;
                if (mc_t > mr)
                    mc_t = mr;
                end
                
                nc_b = nc - k;
                if (nc_b <= 0)
                    nc_b = 1;
                end
                
                nc_t = nc + k;
                if (nc_t > nr)
                    nc_t = nr;
                end
                
                % calculate reduced maps of just the area we're convolving
                reduced_compression_map = compressed_map(mc_b:mc_t, nc_b:nc_t);
                reduced_value_map = value_map(mc_b:mc_t, nc_b:nc_t);
                
                intensity = mean_square_value(reduced_compression_map, reduced_value_map, mc, nc);
                if (intensity >= 0)
                    % found nearby values
                    new_value_map(mc,nc) = 1;
                    reconstructed_map(mc,nc) = sum(intensity);
                end
            end
        end
    end
end

% This function calculates the intensity of the gray color pixel based off
% values around it
function intensity = mean_square_value(reduced_compression_map,reduced_value_map, mx, ny)
    intensity = -1;
    is_empty = 0;
    
    [mi,ni] = size(reduced_value_map);
    
    
    d = zeros(mi*ni); % equal in length to all values being valid
    i = zeros(mi*ni);
    counter = 1; % tracks position in d
    dt = 0;

    % iterate through maps, find values, calculate intensity, return
    for mc = 1:mi
        for nc = 1:ni
            if (reduced_value_map(mc,nc) == 1)
                is_empty = is_empty + 1; % no longer empty
                % calculate the distance, add it to dt, add it to d
                d(counter) = sqrt((mx-mc)^2 + (ny-nc)^2);
                i(counter) = reduced_compression_map(mc,nc); % stores gray value
                dt = dt + d(counter);
                counter = counter + 1; % increment counter
            end
        end
    end
    
    if (is_empty == 0)
        % must have usable values
        return;
    end
    
    % sum the intensity
    intensity = sum(i.*d)/dt;
end

% takes in two vectors of equal size and swaps the values from the second
% into the first vector when the first vector has a value of 1
function im_map = generate_compressed_image(pepper_map, im)
    im_map = zeros(size(pepper_map), 'uint8');
    [mi, ni] = size(pepper_map);
    
    if (size(pepper_map) ~= size(im))
        disp('ERROR: maps must be of equal size');
        return;
    end
    
    % look up which direction matlab stores arrays; may be able to make it
    % faster by swapping height and width
    for mc = 1:mi
        for nc = 1:ni
            % if 1, swap value with im
            if (pepper_map(mc,nc) == 1)
                im_map(mc,nc) = im(mc,nc);
            else 
                im_map(mc,nc) = 255;
            end
        end
    end
end

% Creates a pepper map based off of the orininal image
% function pepper_map = create_pepper_map(im)
% 
%     [mp,np] = size(im);
%     pepper_map = zeros(mp,np);
%     
%     if (mp < 7 || np < 7)
%         disp('Error - submitted image is less than 7 pixels, ending program');
%         return;
%     end
%     
%     for mc = 3:mp-3
%         for nc = 3:np-3
%             
%         end
%     end
% end


function pepper_map = generate_partitioned_peper(mp, np, total)

    pepper_map = zeros(mp,np);

    m1 = round(mp/5);
    m2 = m1*2;
    m3 = m1*3;
    m4 = m1*4;
    m5 = mp;
    
    n1 = round(np/3);
    n2 = n1*2;
    n3 = np;
    
    base = 60;

    pepper_map(1:m1, 1:n1) = generate_binary_pepper(m1,n1,round(total*1/base));
    pepper_map(m1+1:m2, 1:n1) = generate_binary_pepper(m2-m1,n1,round(total*1/base));
    pepper_map(m2+1:m3, 1:n1) = generate_binary_pepper(m3-m2,n1,round(total*4/base));
    pepper_map(m3+1:m4, 1:n1) = generate_binary_pepper(m4-m3,n1,round(total*4/base));
    pepper_map(m4+1:m5, 1:n1) = generate_binary_pepper(m5-m4,n1,round(total*4/base));
    
    pepper_map(1:m1, n1+1:n2) = generate_binary_pepper(m1,n2-n1,round(total*1/30));
    pepper_map(m1+1:m2, n1+1:n2) = generate_binary_pepper(m2-m1,n2-n1,round(total*1/base));
    pepper_map(m2+1:m3, n1+1:n2) = generate_binary_pepper(m3-m2,n2-n1,round(total*15/base));
    pepper_map(m3+1:m4, n1+1:n2) = generate_binary_pepper(m4-m3,n2-n1,round(total*14/base));
    pepper_map(m4+1:m5, n1+1:n2) = generate_binary_pepper(m5-m4,n2-n1,round(total*4/base));
    
    pepper_map(1:m1, n2+1:n3) = generate_binary_pepper(m1,n3-n2,round(total*1/30));
    pepper_map(m1+1:m2, n2+1:n3) = generate_binary_pepper(m2-m1,n3-n2,round(total*1/base));
    pepper_map(m2+1:m3, n2+1:n3) = generate_binary_pepper(m3-m2,n3-n2,round(total*3/base));
    pepper_map(m3+1:m4, n2+1:n3) = generate_binary_pepper(m4-m3,n3-n2,round(total*4/base));
    pepper_map(m4+1:m5, n2+1:n3) = generate_binary_pepper(m5-m4,n3-n2,round(total*4/base));
    
end

% first value should be vector of the correct size, second value should be
% how many pixels you want to allocate. May change value_map into just size
% results
function pepper_map = generate_binary_pepper(mp, np, total)
    count = 0;
    pepper_map = zeros(mp, np, 'uint8');
    
    while (count < total)
        mc = randi(mp);
        nc = randi(np);
        
        if (pepper_map(mc,nc) > 0)
            % don't use, already has value
            continue;
        else
            % set pepper, increment counter
            pepper_map(mc, nc) = 1;
            count = count + 1;
        end
    end
end

