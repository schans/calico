// Copyright (c) 2021 Tigera, Inc. All rights reserved.

// Code generated by lister-gen. DO NOT EDIT.

package v3

import (
	v3 "github.com/projectcalico/api/pkg/apis/projectcalico/v3"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/tools/cache"
)

// NetworkPolicyLister helps list NetworkPolicies.
// All objects returned here must be treated as read-only.
type NetworkPolicyLister interface {
	// List lists all NetworkPolicies in the indexer.
	// Objects returned here must be treated as read-only.
	List(selector labels.Selector) (ret []*v3.NetworkPolicy, err error)
	// NetworkPolicies returns an object that can list and get NetworkPolicies.
	NetworkPolicies(namespace string) NetworkPolicyNamespaceLister
	NetworkPolicyListerExpansion
}

// networkPolicyLister implements the NetworkPolicyLister interface.
type networkPolicyLister struct {
	indexer cache.Indexer
}

// NewNetworkPolicyLister returns a new NetworkPolicyLister.
func NewNetworkPolicyLister(indexer cache.Indexer) NetworkPolicyLister {
	return &networkPolicyLister{indexer: indexer}
}

// List lists all NetworkPolicies in the indexer.
func (s *networkPolicyLister) List(selector labels.Selector) (ret []*v3.NetworkPolicy, err error) {
	err = cache.ListAll(s.indexer, selector, func(m interface{}) {
		ret = append(ret, m.(*v3.NetworkPolicy))
	})
	return ret, err
}

// NetworkPolicies returns an object that can list and get NetworkPolicies.
func (s *networkPolicyLister) NetworkPolicies(namespace string) NetworkPolicyNamespaceLister {
	return networkPolicyNamespaceLister{indexer: s.indexer, namespace: namespace}
}

// NetworkPolicyNamespaceLister helps list and get NetworkPolicies.
// All objects returned here must be treated as read-only.
type NetworkPolicyNamespaceLister interface {
	// List lists all NetworkPolicies in the indexer for a given namespace.
	// Objects returned here must be treated as read-only.
	List(selector labels.Selector) (ret []*v3.NetworkPolicy, err error)
	// Get retrieves the NetworkPolicy from the indexer for a given namespace and name.
	// Objects returned here must be treated as read-only.
	Get(name string) (*v3.NetworkPolicy, error)
	NetworkPolicyNamespaceListerExpansion
}

// networkPolicyNamespaceLister implements the NetworkPolicyNamespaceLister
// interface.
type networkPolicyNamespaceLister struct {
	indexer   cache.Indexer
	namespace string
}

// List lists all NetworkPolicies in the indexer for a given namespace.
func (s networkPolicyNamespaceLister) List(selector labels.Selector) (ret []*v3.NetworkPolicy, err error) {
	err = cache.ListAllByNamespace(s.indexer, s.namespace, selector, func(m interface{}) {
		ret = append(ret, m.(*v3.NetworkPolicy))
	})
	return ret, err
}

// Get retrieves the NetworkPolicy from the indexer for a given namespace and name.
func (s networkPolicyNamespaceLister) Get(name string) (*v3.NetworkPolicy, error) {
	obj, exists, err := s.indexer.GetByKey(s.namespace + "/" + name)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.NewNotFound(v3.Resource("networkpolicy"), name)
	}
	return obj.(*v3.NetworkPolicy), nil
}
