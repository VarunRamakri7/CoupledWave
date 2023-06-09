# Water Animation using coupled SPH and Wave Equations

## Abstract
This thesis project addresses the need for an interactive, real-time water animation technique that can showcase visually convincing effects such as splashes and breaking waves while being computationally inexpensive. Our method couples SPH and wave equations in a one-way manner to simulate the behavior of water in real-time, leveraging OpenGL’s Compute Shaders for interactive performance and a novel Uniform Grid implementation. Through a review of related literature on real-time simulation methods of fluids, and water animation, this thesis presents a feasible algorithm, animations to showcase interesting water effects, and a comparison of computational costs between SPH, wave equations, and the coupled approach. The program renders a water body with a planar surface and discrete particles. This project aims to provide a solution that can meet the needs of various water animation use-cases, such as games, and movies, by offering a computationally efficient technique that can animate water to behave plausibly and showcase essential effects in real-time.

Full paper can be read [here](https://hammer.purdue.edu/articles/thesis/Water_Animation_using_Coupled_SPH_and_Wave_Equations/22655074)


## Animations
### Coupled Approach
<img src="media/couple-init.gif" width=20% height=20%> <img src="media/couple-splash.gif" width=20% height=20%> <img src="media/couple-break.gif" width=20% height=20%>
<img src="media/couple-wake.gif" width=20% height=20%> <img src="media/couple-splash-split.gif" width=20% height=20%>

### Pure SPH Approach
<img src="media/sph-init.gif" width=20% height=20%> <img src="media/sph-break.gif" width=20% height=20%> <img src="media/sph-splash.gif" width=20% height=20%>

### Pure wave equation approach
<img src="media/wave-splash.gif" width=20% height=20%> <img src="media/wave-break.gif" width=20% height=20%> <img src="media/wave-wake.gif" width=20% height=20%>
