/// @file

#define SAFEDIV(X, Y, EPSILON)    (X)/(Y + EPSILON)

void compute_link_displacements(float4 Pl_PR, float4 Pl_PL, float4 P,
                                float4 rl_PR, float4 rl_PL, float4 fr,
                                float4* Dl_PR, float4* Dl_PL)
{
  ////////////////////////////////////////////////////////////////////////////////
  ////////////////// SYNERGIC MOLECULE: LINKED PARTICLE VECTOR ///////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      Ll_PR = Pl_PR - P;                                                  // 1st linked particle vector.
  float4      Ll_PL = Pl_PL - P;                                                  // 3rd linked particle vector.

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////////// SYNERGIC MOLECULE: LINK LENGTH ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      ll_PR = length(Ll_PR);                                              // 1st link length.
  float4      ll_PL = length(Ll_PL);                                              // 3rd link length.

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////////// SYNERGIC MOLECULE: LINK STRAIN ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      epsilon = fr - (float4)(1.0f,1.0f,1.0f,1.0f);                     // Safety margin for division.
  float4      sl_PR = ll_PR - rl_PR;                                            // 1st link strain.
  float4      sl_PL = ll_PL - rl_PL;                                            // 3rd link strain.

  ////////////////////////////////////////////////////////////////////////////////
  //////////////// SYNERGIC MOLECULE: LINKED PARTICLE DISPLACEMENT ///////////////
  ////////////////////////////////////////////////////////////////////////////////
  *Dl_PR = sl_PR*SAFEDIV(Ll_PR, ll_PR, epsilon);                                                            // 1st linked particle displacement.
  *Dl_PL = sl_PL*SAFEDIV(Ll_PL, ll_PL, epsilon);                                                            // 3rd linked particle displacement.
}


float4 compute_particle_force(float4 kl_PR, float4 kl_PL, float4 Dl_PR,
                              float4 Dl_PL, float4 c, float4 V, float4 m,
                              float4 G, float4 fr)
{
  ////////////////////////////////////////////////////////////////////////////////
  //////////////////////// SYNERGIC MOLECULE: ELASTIC FORCE //////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      Fe   = kl_PR*Dl_PR + kl_PL*Dl_PL;           // Elastic force applied to the particle.

  ////////////////////////////////////////////////////////////////////////////////
  //////////////////////// SYNERGIC MOLECULE: VISCOUS FORCE //////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      Fv   = -c*V;                                                      // Viscous force applied to the particle.

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////// SYNERGIC MOLECULE: GRAVITATIONAL FORCE ///////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      Fg   = m*G;                                                       // Gravitational force applied to the particle.

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////////// SYNERGIC MOLECULE: TOTAL FORCE ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      F    = fr*(Fe + Fv + Fg);                                         // Total force applied to the particle.

  return F;
}


__kernel void thekernel(__global float4*    position,
                        __global float4*    color,
                        __global float4*    position_int,
                        __global float4*    velocity,
                        __global float4*    velocity_int,
                        __global float4*    acceleration,
                        __global float4*    acceleration_int,
                        __global float4*    gravity,
                        __global float4*    stiffness,
                        __global float4*    resting,
                        __global float4*    friction,
                        __global float4*    mass,
                        __global int*       index_PR,                     // Indexes of "#1 friend" particles.
                        __global int*       index_PL,                     // Indexes of "#3 friend" particles.
                        __global float4*    freedom,
                        __global float*     DT)
{

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////// GLOBAL INDEX /////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  unsigned int gid = get_global_id(0);                                          // Setting global index "gid"...

  ////////////////////////////////////////////////////////////////////////////////
  /////////////////// SYNERGIC MOLECULE: KINEMATIC VARIABLES /////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      P   = position[gid];                                              // Current particle position.
  float4      V   = velocity[gid];                                              // Current particle velocity.
  float4      A   = acceleration[gid];                                          // Current particle acceleration.

  ////////////////////////////////////////////////////////////////////////////////
  /////////////////// SYNERGIC MOLECULE: DYNAMIC VARIABLES ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      m   = mass[gid];                                                  // Current particle mass.
  float4      G   = gravity[gid];                                               // Current particle gravity field.
  float4      c   = friction[gid];                                              // Current particle friction.
  float4      fr  = freedom[gid];                                               //
  float4      col = color[gid];                                                 // Current particle color.

  ////////////////////////////////////////////////////////////////////////////////
  ////////////////////// SYNERGIC MOLECULE: LINK INDEXES /////////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  // NOTE: 1. the index of a non-existing particle friend must be set to the index of the particle.
  int         il_PR = index_PR[gid];                                       // Setting indexes of 1st linked particle...
  int         il_PL = index_PL[gid];                                       // Setting indexes of 3rd linked particle...

  ////////////////////////////////////////////////////////////////////////////////
  ///////////////// SYNERGIC MOLECULE: LINKED PARTICLE POSITIONS /////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      Pl_PR = position[il_PR];                                           // 1st linked particle position.
  float4      Pl_PL = position[il_PL];                                           // 3rd linked particle position.

  ////////////////////////////////////////////////////////////////////////////////
  //////////////// SYNERGIC MOLECULE: LINK RESTING DISTANCES /////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  float4      rl_PR = resting[il_PR];                                             // 1st linked particle resting distance.
  float4      rl_PL = resting[il_PL];                                             // 3rd linked particle resting distance.

  ////////////////////////////////////////////////////////////////////////////////
  ////////////////////// SYNERGIC MOLECULE: LINK STIFFNESS ///////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  // NOTE: the stiffness of a non-existing link must reset to 0.
  float4      kl_PR = stiffness[il_PR];                                           // 1st link stiffness.
  float4      kl_PL = stiffness[il_PL];                                           // 3rd link stiffness.

  //////////////////////////////////////////////////////////////////////////////
  /////////////////////////////// VERLET INTEGRATION ///////////////////////////
  //////////////////////////////////////////////////////////////////////////////

  // linked particles displacements
  float4      Dl_PR;
  float4      Dl_PL;

  // time step
  float dt = *DT;

  // Calculating acceleration at time t_n...
  compute_link_displacements(Pl_PR, Pl_PL, P, rl_PR, rl_PL, fr, &Dl_PR, &Dl_PL);

  float4 F = compute_particle_force(kl_PR, kl_PL, Dl_PR, Dl_PL, c, V, m, G, fr);

  A = F/m;

  // Calculating and updating position of the center particle...
  P += V*dt + A*dt*dt/2.0f;

  // update intermediate positions in global memory
  position_int[gid] = P;
  velocity_int[gid] = V;
  acceleration_int[gid] = A;

}
