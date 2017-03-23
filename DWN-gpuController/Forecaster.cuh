/*
 *    GPU-accelerated scenario-based stochastic MPC for the operational
 *    management of drinking water networks.
 *    Copyright (C) 2017 Ajay. K. Sampathirao and P. Sopasakis
 *
 *    This library is free software; you can redistribute it and/or
 *    modify it under the terms of the GNU Lesser General Public
 *    License as published by the Free Software Foundation; either
 *    version 2.1 of the License, or (at your option) any later version.
 *
 *    This library is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *    Lesser General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public
 *    License along with this library; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef FORECASTCLASS_CUH_
#define FORECASTCLASS_CUH_
#define VARNAME_N  "N"
#define VARNAME_K  "K"
#define VARNAME_NODES "nodes"
#define VARNAME_NUM_NONLEAF "nNonLeafNodes"
#define VARNAME_NUM_CHILD_TOT "nChildrenTot"
#define VARNAME_DIM_NODE "dimNode"
#define VARNAME_STAGES "stages"
#define VARNAME_NODES_PER_STAGE "nodesPerStage"
#define VARNAME_NODES_PER_STAGE_CUMUL "nodesPerStageCumul"
#define VARNAME_LEAVES "leaves"
#define VARNAME_CHILDREN "children"
#define VARNAME_ANCESTOR "ancestor"
#define VARNAME_NUM_CHILDREN "nChildren"
#define VARNAME_NUM_CHILD_CUMUL "nChildrenCumul"
#define VARNAME_PROB_NODE "probNode"
#define VARNAME_VALUE_NODE "valueNode"
#define VARNAME_DHAT "dHat"
#include "Configuration.h"



/**
 * The uncertainty in the network are water demand and electricity
 * prices. Using a time series models, a nominal future water demand and
 * nominal electricity prices is predicted. The nominal values have
 * error with respect to the actual values. In scenario-based MPC,
 * the error is represented with a scenario tree.
 *
 * A forecaster class contains:
 *   - nominal water demands
 *     - nominal electricity prices
 *     - scenario tree used to represent the error in the predictions
 *       - nodes at a stage
 *       - children of a node
 *       - ancestor of a node
 *       - probability of a node
 *       - value of a node
 *
 * @todo remove print statements
 * @todo sanity check (check that the given file is well formed)
 * @todo new char[65536]: is this good practice?
 */
class Forecaster{

public:

	/*
	 *  Constructor of a DWN entity from a given JSON file.
	 *
 	 * @param pathToFile filename of a JSON file containing
	 * 		     a representation of the scenario tree.
	 */
	Forecaster(
		string pathToFile);
	/**
	 * Default destructor.
	 */
	~Forecaster();

	/*TODO REMOVE Friendship */
	friend class Engine;

	/*TODO REMOVE Friendship */
	friend class SmpcController;
private:
	/**
	 *  Prediction horizon
	 */
	uint_t N;
	/**
	 * Number of scenarios
	 */
	uint_t K;
	/**
	 * Total number of nodes.
	 */
	uint_t nNodes;
	/**
	 * Total number of children.
	 */
	uint_t nChildrenTot;
	/**
	 * Number of non-leaf tree nodes.
	 */
	uint_t nNonleafNodes;
	/**
	 * Dimension of the demand
	 */
	uint_t dimDemand;
	/**
	 * Vector of length nNodes and represents at stage of each node
	 */
	uint_t *stages;
	/**
	 * Vector of length N and represents how many nodes at given stage.
	 */
	uint_t *nodesPerStage;
	/**
	 * Vector of length N and represents the number of nodes past nodes
	 */
	uint_t *nodesPerStageCumul;
	/**
	 * Vector of length K and contains the indexes of the leaf nodes.
	 */
	uint_t *leaves;
	/**
	 * Indices of the children nodes for each node.
	 */
	uint_t *children;
	/**
	 * Vector of length nNodes and contain the index of the ancestor of the node
	 * with root node having the index zero
	 */
	uint_t *ancestor;
	/**
	 * Vector of length nNonLeafNodes and contain the number of children of
	 * each node.
	 */
	uint_t *nChildren;
	/**
	 * Vector of length nNonLeafNodes and contain the sum of past children at node
	 */
	uint_t *nChildrenCumul;
	/**
	 * Probability of a node.
	 */
	real_t *probNode;
	/**
	 * Value on a node.
	 */
	real_t *valueNode;
	/**
	 * Nominal demand predicted
	 */
	real_t *dHat;
};



#endif /* FORECASTCLASS_CUH_ */
