# [Cell Tracking via Proposal Generation and Selection](https://arxiv.org/abs/1705.03386)
[S. U. Akram](https://scholar.google.fi/citations?user=i8UDIQ4AAAAJ&hl=en), [J. Kannala](https://users.aalto.fi/~kannalj1/), L. Eklund & [J. Heikkilä](https://scholar.google.com/citations?user=SCR4RY8AAAAJ),<br/>
<br/>

1. **[Introduction](#introduction)**
1. **[Requirements](#requirements)**
1. **[Instructions](#instructions)**
1. **[Downloads](#downloads)**
1. **[Videos](#videos)**

## [Introduction:](#introduction)
The paper can be found at **[arXiv](https://arxiv.org/abs/1705.03386)** and [cell proposal network code](https://github.com/SaadUllahAkram/CPN) is available at **[github](https://github.com/SaadUllahAkram/CPN)**.
If you find this code useful in your research, please consider citing:

    @article{akram2017a,
        author = {Akram S. U., Kannala J., Eklund L., and Heikkilä J.},
        title = {Cell Tracking via Proposal Generation and Selection},
        journal = {arXiv:1705.03386},
        year = {2017}
    }

The code has many half finished and broken features, which i plan to either remove or fix in the future.
The code was re-structred recently and it may have introduced some bugs, which you may report (especially if they are in parts which are executed) and i will try to fix them.
If and when i fix this code, i may remove the experimental **exp** branch.


## [Requirements:](#requirements)
1. [CPN](https://github.com/SaadUllahAkram/CPN): Cell Proposal Network code.<br/>
    `git clone https://github.com/SaadUllahAkram/CPN.git`
1. [CellTracker](https://github.com/SaadUllahAkram/CellTracker): Cell Tracking code.<br/>
    `git clone https://github.com/SaadUllahAkram/CellTracker.git`
1. [caffe](https://github.com/SaadUllahAkram/caffe_cpn): Faster R-CNN version with crop layer.<br/>
    `git clone https://github.com/SaadUllahAkram/caffe_cpn.git`
1. [BIA](https://github.com/SaadUllahAkram/BIA): a collection of useful functions.<br/>
    `git clone https://github.com/SaadUllahAkram/BIA.git`
1. [MATLAB](https://www.mathworks.com/products/matlab.html)<br/>
1. [Gurobi](http://www.gurobi.com/)


## [Instructions:](#instructions)
1. Set `Gurobi, Caffe, ISBI CTC data` paths in `get_paths.m` function in [BIA](https://github.com/SaadUllahAkram/BIA):
1. activate caffe using: `bia.caffe.activate('cpn', gpu_id);`
1. Download [Cell Tracking Challenge](http://www.codesolorzano.com/Challenges/CTC/Welcome.html) data.

#### Testing (will be added soon)
1. run `demo_test_tracker()`

#### Training
1. run `demo_train_tracker()`

## [Downloads:](#downloads)
Trained models and demo will be added soon.

## [Videos](#videos)
[Playlist](https://www.youtube.com/playlist?list=PLcJbqpL67krDzNCwduoVQqnpvl7nl15Rq)<br/>

Videos show the boundaries of cells within the field of interest.
Color of cell boundaries identifies the track identity and color of each track remains same for the whole sequence.
Field of interest, the region inside which cells are tracked, is highlighted with the red rectangle.
Cell events are highlighted: enter (green boxes), leave (red boxes), mitosis (red circle) and daughter cells (green circle). <br/>

[![CPN Tracking Video Playlist](https://img.youtube.com/vi/aRy7Rh4JNt8/0.jpg)](https://www.youtube.com/watch?v=aRy7Rh4JNt8&list=PLcJbqpL67krDzNCwduoVQqnpvl7nl15Rq "CPN Tracking Video Playlist")

