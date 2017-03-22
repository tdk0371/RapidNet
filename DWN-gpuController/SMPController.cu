/*
 * SMPController.cu
 *
 *  Created on: Mar 16, 2017
 *      Author: Ajay Kumar Sampathirao
 */
#include <cuda_device_runtime_api.h>
#include "cuda_runtime.h"
#include "cublas_v2.h"

#include "SMPController.cuh"
//#include "cudaKernalHeader.cuh"

SMPCController::SMPCController(Engine *myEngine){
	cout << "Allocation of controller memory" << endl;
	ptrMyEngine = myEngine;
	uint_t nx = ptrMyEngine->ptrMyNetwork->NX;
	uint_t nu = ptrMyEngine->ptrMyNetwork->NU;
	uint_t nv = ptrMyEngine->ptrMyNetwork->NV;
	uint_t ns = ptrMyEngine->ptrMyForecaster->K;
	uint_t nodes = ptrMyEngine->ptrMyForecaster->N_NODES;
	MAX_ITERATIONS  = 500;
	stepSize = 1e-4;

	_CUDA( cudaMalloc((void**)&devVecX, nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecU, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecV, nv*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecPsi, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecAcceleratedXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecAcceleratedPsi, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecPrimalXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecPrimalPsi, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecDualXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecDualPsi, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecUpdateXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecUpdatePsi, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devPrimalInfeasibilty, (2*nx + nu)*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecQ, ns*nx*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecR, ns*nv*sizeof(real_t)) );

	_CUDA( cudaMalloc((void**)&devPtrVecX, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecU, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecV, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecAcceleratedXi, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecAcceleratedPsi, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecPrimalXi, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecPrimalPsi, nodes*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecQ, ns*sizeof(real_t*)) );
	_CUDA( cudaMalloc((void**)&devPtrVecR, ns*sizeof(real_t*)) );

	real_t** ptrVecX = new real_t*[nodes];
	real_t** ptrVecU = new real_t*[nodes];
	real_t** ptrVecV = new real_t*[nodes];
	real_t** ptrVecAcceleratedXi = new real_t*[nodes];
	real_t** ptrVecAcceleratedPsi = new real_t*[nodes];
	real_t** ptrVecPrimalXi = new real_t*[nodes];
	real_t** ptrVecPrimalPsi = new real_t*[nodes];
	real_t** ptrVecQ = new real_t*[ns];
	real_t** ptrVecR = new real_t*[ns];

	for(int iLeaf = 0; iLeaf < ns; iLeaf++){
		ptrVecQ[iLeaf] = &devVecQ[iLeaf*nx];
		ptrVecR[iLeaf] = &devVecR[iLeaf*nv];
	}
	for(int iNode = 0; iNode < nodes; iNode++){
		ptrVecX[iNode] = &devVecX[iNode*nx];
		ptrVecU[iNode] = &devVecU[iNode*nu];
		ptrVecV[iNode] = &devVecV[iNode*nv];
		ptrVecAcceleratedXi[iNode] = &devVecAcceleratedXi[2*iNode*nx];
		ptrVecAcceleratedPsi[iNode] = &devVecAcceleratedPsi[iNode*nu];
		ptrVecPrimalXi[iNode] = &devVecPrimalXi[2*iNode*nx];
		ptrVecPrimalPsi[iNode] = &devVecPrimalPsi[iNode*nu];
	}

	_CUDA( cudaMemset(devVecU, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecAcceleratedXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecAcceleratedPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecUpdateXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecUpdatePsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPrimalXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPrimalPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecDualXi, 0, 2*nx*nodes*sizeof(real_t)));
	_CUDA( cudaMemset(devVecDualPsi, 0, nu*nodes*sizeof(real_t)) );

	_CUDA( cudaMemcpy(devPtrVecX, ptrVecX, nodes*sizeof(real_t*), cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecU, ptrVecU, nodes*sizeof(real_t*), cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecV, ptrVecV, nodes*sizeof(real_t*), cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecAcceleratedXi, ptrVecAcceleratedXi, nodes*sizeof(real_t*), cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecAcceleratedPsi, ptrVecAcceleratedPsi, nodes*sizeof(real_t*), cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecPrimalXi, ptrVecPrimalXi, nodes*sizeof(real_t*),cudaMemcpyHostToDevice) );
	_CUDA( cudaMemcpy(devPtrVecPrimalPsi, ptrVecPrimalPsi, nodes*sizeof(real_t*),cudaMemcpyHostToDevice) );

	delete [] ptrVecX;
	delete [] ptrVecU;
	delete [] ptrVecV;
	delete [] ptrVecAcceleratedXi;
	delete [] ptrVecAcceleratedPsi;
	delete [] ptrVecPrimalXi;
	delete [] ptrVecPrimalPsi;
}

void SMPCController::dualExtrapolationStep(real_t lambda){
	uint_t nodes = ptrMyEngine->ptrMyForecaster->N_NODES;
	uint_t nx = ptrMyEngine->ptrMyNetwork->NX;
	uint_t nu = ptrMyEngine->ptrMyNetwork->NU;
	float alpha;
	// w = (1 + \lambda)y_k - \lambda y_{k-1}
	_CUDA(cudaMemcpy(devVecAcceleratedXi, devVecUpdateXi, 2*nx*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice) );
	_CUDA(cudaMemcpy(devVecAcceleratedPsi, devVecUpdatePsi, nu*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice) );
	alpha = 1 + lambda;
	_CUBLAS(cublasSscal_v2(ptrMyEngine->handle, 2*nx*nodes, &alpha, devVecAcceleratedXi, 1));
	_CUBLAS(cublasSscal_v2(ptrMyEngine->handle, nu*nodes, &alpha, devVecAcceleratedPsi, 1));
	alpha = -lambda;
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, 2*nx*nodes, &alpha, devVecXi, 1, devVecAcceleratedXi, 1));
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nu*nodes, &alpha, devVecPsi, 1, devVecAcceleratedPsi, 1));
	// y_{k} = y_{k-1}
	_CUDA(cudaMemcpy(devVecXi, devVecUpdateXi, 2*nx*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
	_CUDA(cudaMemcpy(devVecPsi, devVecUpdatePsi, nu*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
}

void SMPCController::solveStep(){

	DWNnetwork *ptrMyNetwork = ptrMyEngine->ptrMyNetwork;
	Forecaster *ptrMyForecaster = ptrMyEngine->ptrMyForecaster;
	real_t *devTempVecR, *devTempVecQ;
	uint_t nx = ptrMyNetwork->NX;
	uint_t nu = ptrMyNetwork->NU;
	uint_t nv = ptrMyNetwork->NV;
	uint_t ns = ptrMyForecaster->K;
	uint_t N =  ptrMyForecaster->N;
	uint_t nodes = ptrMyForecaster->N_NODES;
	uint_t iStageCumulNodes, iStageNodes, prevStageNodes, prevStageCumulNodes;
	real_t scale[2] = {-0.5, 1};
	real_t alpha = 1;
	real_t beta = 0;

	cout<< nx << " " << nu << " " << ns << endl;
	_CUDA( cudaMalloc((void**)&devTempVecQ, ns*nx*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devTempVecR, ns*nv*sizeof(real_t)) );
	_CUDA( cudaMemcpy(ptrMyEngine->devMatSigma, ptrMyEngine->devVecBeta, nv*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice) );

	for(int iStage = N-1;iStage > -1;iStage--){
		iStageCumulNodes = ptrMyForecaster->nodesPerStageCumul[iStage];
		iStageNodes = ptrMyForecaster->nodesPerStage[iStage];
		if(iStage < N-1){
			// sigma=sigma+r
			_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, iStageNodes*nv, &alpha, devVecR, 1,
					&ptrMyEngine->devMatSigma[iStageCumulNodes*nv],1));
		}
		// v=Omega*sigma
		_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, nv, &scale[0], (const float**)
				&ptrMyEngine->devPtrMatOmega[iStageCumulNodes], nv, (const float**)&ptrMyEngine->devPtrMatSigma[iStageCumulNodes],
				nv, &beta, &devPtrVecV[iStageCumulNodes], nv, iStageNodes));

		if(iStage < N-1){
			// v=Theta*q+v
			_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, nx, &alpha, (const float**)
					&ptrMyEngine->devPtrMatTheta[iStageCumulNodes], nv, (const float**)devPtrVecQ, nx,
					&alpha, &devPtrVecV[iStageCumulNodes], nv, iStageNodes));
		}

		// v=Psi*psi+v
		_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, nu, &alpha, (const float**)
				&ptrMyEngine->devPtrMatPsi[iStageCumulNodes], nv, (const float**)&devPtrVecAcceleratedPsi[iStageCumulNodes],
				nu, &alpha, &devPtrVecV[iStageCumulNodes], nv, iStageNodes));

		// v=Phi*xi+v
		_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, 2*nx, &alpha, (const float**)
				&ptrMyEngine->devPtrMatPhi[iStageCumulNodes], nv, (const float**)&devPtrVecAcceleratedXi[iStageCumulNodes],
				2*nx, &alpha, &devPtrVecV[iStageCumulNodes], nv, iStageNodes));

		// r=sigma
		_CUDA(cudaMemcpy(devVecR, &ptrMyEngine->devMatSigma[iStageCumulNodes*nv], nv*iStageNodes*sizeof(real_t), cudaMemcpyDeviceToDevice));

		// r=D*xi+r
		_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, 2*nx, &alpha, (const float**)
				&ptrMyEngine->devPtrMatD[iStageCumulNodes], nv, (const float**)&devPtrVecAcceleratedXi[iStageCumulNodes],
				2*nx, &alpha, devPtrVecR, nv, iStageNodes));

		// r=f*psi+r
		_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, nu, &alpha, (const float**)
				&ptrMyEngine->devPtrMatF[iStageCumulNodes], nv, (const float**)&devPtrVecAcceleratedPsi[iStageCumulNodes],
				nu, &alpha, devPtrVecR, nv, iStageNodes));

		if(iStage < N-1){
			// r=g*q+r
			_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nv, 1, nx, &alpha, (const float**)
					&ptrMyEngine->devPtrMatG[iStageCumulNodes], nv, (const float**)devPtrVecQ, nx, &alpha, devPtrVecR, nv, iStageNodes));
		}

		if(iStage < N-1){
			// q=F'xi+q
			_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_T, CUBLAS_OP_N, nx, 1, 2*nx, &alpha, (const float**)
					&ptrMyEngine->devPtrMatF[iStageCumulNodes], 2*nx, (const float**)&devPtrVecAcceleratedXi[iStageCumulNodes],
					2*nx, &alpha, devPtrVecQ, nx, iStageNodes));
		}else{
			// q=F'xi
			_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_T, CUBLAS_OP_N, nx, 1, 2*nx, &alpha, (const float**)
					&ptrMyEngine->devPtrMatF[iStageCumulNodes], 2*nx, (const float**)&devPtrVecAcceleratedXi[iStageCumulNodes],
					2*nx, &beta, devPtrVecQ, nx, iStageNodes));
		}
		if(iStage > 0){
			prevStageNodes = ptrMyForecaster->nodesPerStage[iStage - 1];
			prevStageCumulNodes = ptrMyForecaster->nodesPerStageCumul[iStage - 1];
			if( (iStageNodes - prevStageNodes) > 0 ){
				solveSumChildren<<<prevStageNodes, nx>>>(devVecQ, devTempVecQ, ptrMyEngine->devTreeNumChildren,
						ptrMyEngine->devTreeNumChildrenCumul, prevStageCumulNodes, prevStageNodes, iStage - 1, nx);
				solveSumChildren<<<prevStageNodes, nx>>>(devVecR, devTempVecR, ptrMyEngine->devTreeNumChildren,
						ptrMyEngine->devTreeNumChildrenCumul, prevStageCumulNodes, prevStageNodes, iStage - 1 , nv);
				_CUDA(cudaMemcpy(devVecR, devTempVecR, prevStageNodes*nv*sizeof(real_t),cudaMemcpyDeviceToDevice));
				_CUDA(cudaMemcpy(devVecQ, devTempVecQ, prevStageNodes*nx*sizeof(real_t),cudaMemcpyDeviceToDevice));
			}
		}
	}

	// Forward substitution
	_CUDA(cudaMemcpy(devVecU, ptrMyEngine->devVecUhat, nodes*nu*sizeof(real_t), cudaMemcpyDeviceToDevice));

	for(int iStage = 0;iStage < N;iStage++){
		iStageNodes = ptrMyForecaster->nodesPerStage[iStage];
		iStageCumulNodes = ptrMyForecaster->nodesPerStageCumul[iStage];
		if(iStage == 0){
			// x=p, u=h
			_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nv, &alpha, ptrMyEngine->devVecPreviousUhat, 1, devVecV, 1));
			_CUDA( cudaMemcpy(devVecX, ptrMyEngine->devVecCurrentState, nx*sizeof(real_t), cudaMemcpyDeviceToDevice) );
			// x=x+w
			_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nx, &alpha, ptrMyEngine->devVecE, 1, devVecX, 1));
			// u=Lv+\hat{u}
			_CUBLAS(cublasSgemv_v2(ptrMyEngine->handle, CUBLAS_OP_N, nu, nv, &alpha, ptrMyEngine->devSysMatL,
					nu, devVecV, 1, &alpha, devVecU, 1) );
			// x=x+Bu
			_CUBLAS(cublasSgemv_v2(ptrMyEngine->handle, CUBLAS_OP_N, nx, nu, &alpha, ptrMyEngine->devSysMatB,
					nx, devVecU, 1, &alpha, devVecX, 1) );

		}else{
			prevStageCumulNodes = ptrMyForecaster->nodesPerStageCumul[iStage - 1];
			if((ptrMyForecaster->nodesPerStage[iStage] - ptrMyForecaster->nodesPerStage[iStage-1]) > 0){
				// v_k=v_{k-1}+v_k
				solveChildNodesUpdate<<<iStageNodes, nv>>>(&devVecV[prevStageCumulNodes*nv], &devVecV[iStageCumulNodes*nv],
						ptrMyForecaster->ancestor, iStageCumulNodes, nv);
				// u_k=Lv_k+\hat{u}_k
				_CUBLAS(cublasSgemm_v2(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nu, iStageNodes, nv, &alpha,
						ptrMyEngine->devSysMatL, nu, &devVecV[iStageCumulNodes*nv], nv, &alpha, &devVecU[iStageCumulNodes*nu], nu));
				// x=w
				_CUDA(cudaMemcpy(&devVecX[iStageCumulNodes*nx], &ptrMyEngine->devVecE[iStageCumulNodes*nx],
						iStageNodes*nx*sizeof(real_t), cudaMemcpyDeviceToDevice));
				// x=x+Bu
				_CUBLAS(cublasSgemm_v2(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nx, iStageCumulNodes, nu, &alpha,
						ptrMyEngine->devSysMatB, nx, &devVecU[iStageCumulNodes*nu], nu, &alpha, &devVecX[iStageCumulNodes*nx], nx));
				// x_{k+1}=x_k
				solveChildNodesUpdate<<<iStageNodes, nx>>>(&devVecX[prevStageCumulNodes*nx], &devVecX[iStageCumulNodes*nx],
						ptrMyForecaster->ancestor, iStageCumulNodes, nx);
			}else{
				// v_k=v_{k-1}+v_k
				_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nv*iStageNodes, &alpha, &devVecV[prevStageCumulNodes*nv], 1,
						&devVecV[iStageCumulNodes*nv], 1));
				// u_k=Lv_k+\hat{u}_k
				_CUBLAS(cublasSgemm_v2(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nu, iStageNodes, nv, &alpha,
						ptrMyEngine->devSysMatL, nu, &devVecV[iStageCumulNodes*nv], nv, &alpha, &devVecU[iStageCumulNodes*nu], nu));
				// x_{k+1}=x_{k}
				_CUDA(cudaMemcpy(&devVecX[iStageCumulNodes*nx], &devVecX[prevStageCumulNodes*nx], nx*iStageNodes*sizeof(real_t),
						cudaMemcpyDeviceToDevice));
				// x=x+w
				_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nx*iStageNodes, &alpha, &ptrMyEngine->devVecE[iStageCumulNodes*nx],
						1, &devVecX[iStageCumulNodes*nx], 1));
				// x=x+Bu
				_CUBLAS(cublasSgemm_v2(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nx, iStageNodes, nu, &alpha,
						ptrMyEngine->devSysMatB, nx, &devVecU[iStageCumulNodes*nu], nu, &alpha, &devVecX[iStageCumulNodes*nx], nx));
			}
		}
	}/**/

	_CUDA(cudaFree(devTempVecQ));
	_CUDA(cudaFree(devTempVecR));
	devTempVecQ = NULL;
	ptrMyNetwork = NULL;
	ptrMyForecaster = NULL;

	//free(ptr_x_c);
	//free(x_c);
	//free(y_c);
}

void SMPCController::proximalFunG(){
	DWNnetwork *ptrMyNetwork = ptrMyEngine->ptrMyNetwork;
	Forecaster *ptrMyForecaster = ptrMyEngine->ptrMyForecaster;
	uint_t nodes = ptrMyEngine->ptrMyForecaster->N_NODES;
	uint_t nx = ptrMyEngine->ptrMyNetwork->NX;
	uint_t nu = ptrMyEngine->ptrMyNetwork->NU;
	real_t alpha = 1;
	real_t negAlpha = -1;
	real_t beta = 0;
	real_t penaltyScalar;
	real_t invLambda = 1/stepSize;
	real_t distanceXs, distanceXcst;
	real_t *devSuffleVecXi;
	real_t *devVecDiffXi;
	_CUDA( cudaMalloc((void**)&devSuffleVecXi, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMalloc((void**)&devVecDiffXi, 2*nx*nodes*sizeof(real_t)) );
	// primalDual = Hx
	_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, 2*nx, 1, nx, &alpha, (const float**)
			ptrMyEngine->devPtrSysMatF, 2*nx, (const float**)devPtrVecX, 2*nx, &beta, devPtrVecPrimalXi, 2*nx, nodes) );
	_CUBLAS(cublasSgemmBatched(ptrMyEngine->handle, CUBLAS_OP_N, CUBLAS_OP_N, nu, 1, nu, &alpha, (const float**)
			ptrMyEngine->devPtrSysMatG, nu, (const float**)devPtrVecU, nu, &beta, devPtrVecPrimalPsi, nu, nodes) );
	// Hx + \lambda^{-1}w
	_CUDA( cudaMemcpy(devVecDualXi, devPtrVecPrimalXi, 2*nodes*nx*sizeof(real_t), cudaMemcpyDeviceToDevice) );
	_CUDA( cudaMemcpy(devVecDualPsi, devPtrVecPrimalPsi, nodes*nu*sizeof(real_t), cudaMemcpyDeviceToDevice) );
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, 2*nx*nodes, &invLambda, devVecAcceleratedXi, 1, devVecDualXi, 1) );
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nu*nodes, &invLambda, devVecAcceleratedPsi, 1, devVecDualPsi, 1) );

	_CUDA( cudaMemcpy(devVecDiffXi, devVecDualXi, 2*nx*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice) );
	// proj(xi|X), proj(xi|Xsafe)
	projectionBox<<<nodes, nx>>>(devVecDualXi, ptrMyEngine->devSysXmin, ptrMyEngine->devSysXmax, 2*nx, 0, nx*nodes);
	projectionBox<<<nodes, nx>>>(devVecDualXi, ptrMyEngine->devSysXs, ptrMyEngine->devSysXsUpper, 2*nx, nx, nx*nodes);
	// x-proj(x)
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, 2*nx*nodes, &negAlpha, devVecDualXi, 1, devVecDiffXi, 1) );
	shuffleVector<<<nodes, 2*nx>>>(devSuffleVecXi, devVecDiffXi, nx, 2, nodes);
	_CUBLAS(cublasSnrm2_v2(ptrMyEngine->handle, nx*nodes, devSuffleVecXi, 1, &distanceXcst));
	if(distanceXcst > invLambda*ptrMyNetwork->penaltyStateX){
		penaltyScalar = 1-1/distanceXcst;
		additionVectorOffset<<<nodes, nx>>>(devVecDualXi, devVecDiffXi, penaltyScalar, 2*nx, 0, nx*nodes);
	}
	_CUBLAS(cublasSnrm2_v2(ptrMyEngine->handle, nx*nodes, &devSuffleVecXi[nx*nodes], 1, &distanceXs));
	if(distanceXs > invLambda*ptrMyNetwork->penaltySafetyX){
		penaltyScalar = 1-1/distanceXs;
		additionVectorOffset<<<nodes, nx>>>(devVecDualXi, devVecDiffXi, penaltyScalar, 2*nx, nx, nx*nodes);
	}
	projectionBox<<<nodes, nu>>>(devVecDualPsi, ptrMyEngine->devSysUmin, ptrMyEngine->devSysUmax, nu, 0, nu*nodes);
	_CUDA( cudaFree(devSuffleVecXi) );
	_CUDA( cudaFree(devVecDiffXi) );
	devSuffleVecXi = NULL;
	devVecDiffXi = NULL;
	ptrMyNetwork = NULL;
	ptrMyForecaster = NULL;
}

void SMPCController::dualUpdate(){
	uint_t nodes = ptrMyEngine->ptrMyForecaster->N_NODES;
	uint_t nx = ptrMyEngine->ptrMyNetwork->NX;
	uint_t nu = ptrMyEngine->ptrMyNetwork->NU;
	real_t negAlpha = -1;
	//Hx - z
	_CUDA(cudaMemcpy(devPrimalInfeasibilty, devVecPrimalXi, 2*nx*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
	_CUDA(cudaMemcpy(&devPrimalInfeasibilty[2*nx*nodes], devVecPrimalPsi, nu*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, 2*nx*nodes, &negAlpha, devVecDualXi, 1, devPrimalInfeasibilty, 1));
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nu*nodes, &negAlpha, devVecDualPsi, 1, &devPrimalInfeasibilty[2*nx*nodes], 1));
	// y = w + \lambda(Hx - z)
	_CUDA( cudaMemcpy(devVecUpdateXi, devVecAcceleratedXi, 2*nx*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
	_CUDA( cudaMemcpy(devVecUpdatePsi, devVecAcceleratedPsi, nu*nodes*sizeof(real_t), cudaMemcpyDeviceToDevice));
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, 2*nx*nodes, &stepSize, devPrimalInfeasibilty, 1, devVecUpdateXi, 1) );
	_CUBLAS(cublasSaxpy_v2(ptrMyEngine->handle, nu*nodes, &stepSize, &devPrimalInfeasibilty[2*nx*nodes], 1, devVecUpdatePsi, 1) );
}


void SMPCController::algorithmApg(){
	uint_t nodes = ptrMyEngine->ptrMyForecaster->N_NODES;
	uint_t nx = ptrMyEngine->ptrMyNetwork->NX;
	uint_t nu = ptrMyEngine->ptrMyNetwork->NU;
	_CUDA( cudaMemset(devVecXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecAcceleratedXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecAcceleratedPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecUpdateXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecUpdatePsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPrimalXi, 0, 2*nx*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecPrimalPsi, 0, nu*nodes*sizeof(real_t)) );
	_CUDA( cudaMemset(devVecDualXi, 0, 2*nx*nodes*sizeof(real_t)));
	_CUDA( cudaMemset(devVecDualPsi, 0, nu*nodes*sizeof(real_t)) );

	real_t theta[2] = {1, 1};
	real_t lambda;

	for (int iter = 0; iter < MAX_ITERATIONS; iter++){
		lambda = theta[1]*(1/theta[0] - 1);
		dualExtrapolationStep(lambda);
		solveStep();
		proximalFunG();
		dualUpdate();
		theta[1] = 0.5*(sqrt(pow(theta[0], 4) + 4*theta[0]) - pow(theta[0], 2));
	}

	//dualExtrapolationStep(devPtrVecAcceleratedXi, devVecXi, devVecUpdateXi, lambda, 2*nx*nodes);
	//dualExtrapolationStep(devPtrVecAcceleratedPsi, devVecPsi, devVecUpdatePsi, lambda, nu*nodes);
	//dualUpdate(devVecUpdateXi, devPtrVecAcceleratedXi, devPtrVecPrimalXi, devVecDualXi, stepSize, 2*nodes*nx);
	//dualUpdate(devVecUpdatePsi, devPtrVecAcceleratedPsi, devPtrVecPrimalPsi, devVecDualPsi, stepSize, nodes*nu);
}

void SMPCController::controllerSmpc(){
	ptrMyEngine->updateStateControl();
	ptrMyEngine->eliminateInputDistubanceCoupling();
	algorithmApg();
}

SMPCController::~SMPCController(){
	cout << "removing the memory of the controller" << endl;
	_CUDA( cudaFree(devVecX) );
	_CUDA( cudaFree(devVecU) );
	_CUDA( cudaFree(devVecV) );
	_CUDA( cudaFree(devVecXi) );
	_CUDA( cudaFree(devVecPsi) );
	_CUDA( cudaFree(devVecAcceleratedXi) );
	_CUDA( cudaFree(devVecAcceleratedPsi) );
	_CUDA( cudaFree(devVecPrimalXi) );
	_CUDA( cudaFree(devVecPrimalPsi) );
	_CUDA( cudaFree(devVecDualXi) );
	_CUDA( cudaFree(devVecDualPsi) );
	_CUDA( cudaFree(devVecUpdateXi) );
	_CUDA( cudaFree(devVecUpdatePsi) );
	_CUDA( cudaFree(devPrimalInfeasibilty) );

	_CUDA( cudaFree(devPtrVecX) );
	_CUDA( cudaFree(devPtrVecU) );
	_CUDA( cudaFree(devPtrVecV) );
	_CUDA( cudaFree(devPtrVecAcceleratedXi) );
	_CUDA( cudaFree(devPtrVecAcceleratedPsi) );
	_CUDA( cudaFree(devPtrVecPrimalXi) );
	_CUDA( cudaFree(devPtrVecPrimalPsi) );
}

