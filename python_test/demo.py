import numpy as np
import os

def load_bin_file(filepath):
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File {filepath} not found.")
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
        values = [int(line.strip(), 2) for line in lines if line.strip()]
    return np.array(values, dtype=np.int32)


def twos_complement(bin_str):
    bits = len(bin_str)
    val = int(bin_str, 2)
    if val >= 2**(bits - 1):
        val -= 2**bits
    return val


def load_kernels(input):
    input = input.astype(np.int32)
    kernels = np.zeros((8, 3, 3), dtype=np.int32)
    biases = np.zeros(8, dtype=np.int32)
    scales = np.zeros(8, dtype=np.int32)
    for i in range(8):
        for j in range(3):
            for k in range(3):
                kernels[i, j, k] = twos_complement(bin(input[i * 16 + j * 3 + k])[2:].zfill(8))
        biases[i] = twos_complement(bin((input[i * 16 + 9] << 16) + (input[i * 16 + 10] << 8) + input[i * 16 + 11])[2:].zfill(24))
        scales[i] = twos_complement(bin((input[i * 16 + 12] << 24) + (input[i * 16 + 13] << 16) + (input[i * 16 + 14] << 8) + input[i * 16 + 15])[2:].zfill(32))
    return kernels, biases, scales


def bitmap_decode(bitmap: np.ndarray, values: np.ndarray, shape=(32, 32), skipped_val=0):
    flat = []
    idx = 0
    for bit in bitmap.flatten():
        if bit == 1:
            flat.append(values[idx])
            idx += 1
        else:
            flat.append(skipped_val)
    return np.array(flat, dtype=np.uint8).reshape(shape)


def conv2d(img, kernel, bias=0, padding=1):
    padded = np.pad(img, pad_width=padding, mode='constant', constant_values=0)
    out = np.zeros_like(img, dtype=np.int32)
    k_h, k_w = kernel.shape

    for i in range(out.shape[0]):
        for j in range(out.shape[1]):
            region = padded[i:i+k_h, j:j+k_w]
            out[i, j] = np.sum(region * kernel) + bias
    return out


def relu(x):
    return np.maximum(0, x).astype(np.uint32)


def max_pooling(img, size=2):
    h, w = img.shape
    pooled = np.zeros((h//size, w//size), dtype=img.dtype)
    for i in range(0, h, size):
        for j in range(0, w, size):
            pooled[i//size, j//size] = np.max(img[i:i+size, j:j+size])
    return pooled


def quantize(img, scale):
    scaled = np.round(img / (2 ** 32) * scale).astype(np.uint32)
    return scaled


def bitmap_encode(img):
    skipped_val = img[0, 0]
    bitmap = (img != skipped_val).astype(np.uint8)
    values = img[bitmap == 1]
    return bitmap, skipped_val, values


def write_results(filepath, bitmasks, skipped_vals, values):
    with open(filepath, 'w') as f:
        for i in range(8):
            for j in bitmasks[i]:
                for k in range(16):
                    f.write(f"{j[k]}")
                    if k % 8 == 7:
                        f.write("\n")
            f.write(f"{skipped_vals[i]:08b}\n")
            for j in range(255):
                if (j < len(values[i])):
                    f.write(f"{int(values[i][j]):08b}\n")
                else:
                    f.write("XXXXXXXX\n")


def write_bin_mask(bitmap, filepath):
    with open(filepath, 'w') as f:
        for _, b in enumerate(bitmap):
            f.write(f"{b}\n")


def write_img(img, filepath):
    with open(filepath, 'w') as f:
        for i in range(img.shape[0]):
            for j in range(img.shape[1]):
                f.write(f"{img[i, j]:03d} ")
            f.write('\n')


def compare_results(result_file, golden_file, placeholder_value='X'):
    with open(result_file, 'r') as f:
        result_data = [line.strip() for line in f.readlines()]
    
    with open(golden_file, 'r') as f:
        golden_data = [line.strip() for line in f.readlines()]
    
 
    if len(result_data) != len(golden_data):
        print("Error: The number of lines in result and golden data do not match.")
        return

    mismatch_found = False
    for i in range(len(result_data)):
        result_row = result_data[i]
        golden_row = golden_data[i]
        
        result_filtered = [char for char in result_row if char != placeholder_value]
        golden_filtered = [char for char in golden_row if char != placeholder_value]
        
        if result_filtered != golden_filtered:
            mismatch_found = True
            print(f"Mismatch found at line {i + 1}:")
            print(f"Result: {result_row}")
            print(f"Golden: {golden_row}")
    
    if not mismatch_found:
        print("The result and golden data match perfectly!")
    else:
        print("There are mismatches between the result and golden data.")


def main(p):
    input_data = load_bin_file(f'../1132_midterm/00_TESTBED/test_patterns/{p}.dat')
    
    # generate 2D bitmask
    bitmask = np.zeros((32, 32), dtype=np.uint8)
    for i in range(32):
        for j in range(32):
            bitmask[i, j] = (input_data[i * 4 + j // 8] >> (7 - (j % 8))) & 1
    
    # show real bitmask in input data
    for i in range(32):
        print(" ".join(str(bitmask[i, j]) for j in range(32)))  
    print()    
    write_bin_mask(bitmask, f'./python_test/python_result/{p}_bitmask.dat')
    
    # show original image
    img = bitmap_decode(bitmask, input_data[129:], shape=(32, 32), skipped_val=0)
    for i in range(32):
        print(" ".join(f"{img[i, j]:3d}" for j in range(32))) 
    print()
    write_img(img, f'./python_test/python_result/{p}_original_img.dat')

    # show parameters
    kernels, biases, scales = load_kernels(input_data[1152:])
    for i in range(8):
        print(f"Kernel {i}: \n{kernels[i]}")
        print(f"Bias {i}: {biases[i]}")
        print(f"Scale (which should be >>32) {i}: {scales[i]}")
        print("")
    

    conv_imgs = np.zeros((8, 32, 32), dtype=np.int32)
    quantized_imgs = np.zeros((8, 16, 16), dtype=np.uint32)
    bitmasks = []
    skipped_vals = []
    values = []
    
    for i in range(8):
        conv_imgs[i] = conv2d(img, kernels[i], bias=biases[i])
        conv_imgs[i] = relu(conv_imgs[i])
        write_img(conv_imgs[i], f'./python_test/python_result/{p}_conv_img_{i}.dat')
        
        quantized_imgs[i] = (max_pooling(conv_imgs[i]))
        quantized_imgs[i] = quantize(quantized_imgs[i], scales[i])
        
        for k in range(16):
            print(" ".join(f"{quantized_imgs[i][k, j]:3d}" for j in range(16))) 
        print()
        write_img(quantized_imgs[i], f'./python_test/python_result/{p}_quantized_img_{i}.dat')
        
        bitmask, skipped_val, value = bitmap_encode(quantized_imgs[i])
        bitmasks.append(bitmask)
        skipped_vals.append(skipped_val)
        values.append(value)
        
    write_results(f'./python_test/python_result/{p}_output.dat', bitmasks, skipped_vals, values)
    return p




if __name__ == "__main__":
    idx = input("please input current index of testing data: ")
    p = "p"+idx
    main(p)
    compare_results(f'./python_result/{p}_output.dat', f'./1132_midterm/00_TESTBED/test_patterns/{p}_golden.dat')
