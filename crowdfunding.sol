// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IMyToken {
    function getTokenPriceInUSD() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);
}

contract CrowdFundEasy {
    //state variables
    IMyToken token;

    //struct
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 fundRaise;
        uint256 duration;
    }

    //mapping
    Campaign[] campaignLists;
    mapping(uint256 => mapping(address => uint256)) contributorRecords;

    /**
     * @param _token list of allowed token addresses
     */
    constructor(address _token) {
        token = IMyToken(_token);
    }

    /**
     * @notice createCampaign allows anyone to create a campaign
     * @param _goal amount of funds to be raised in USD
     * @param _duration the duration of the campaign in seconds
     */
    function createCampaign(uint256 _goal, uint256 _duration) external {
        require(_goal > 0 && _duration > 0);
        campaignLists.push(
            Campaign(msg.sender, _goal, 0, (_duration + block.timestamp))
        );
    }

    /**
     * @dev contribute allows anyone to contribute to a campaign
     * @param _id the id of the campaign
     * @param _amount the amount of tokens to contribute
     */
    function contribute(uint256 _id, uint256 _amount) external {
        require(_amount > 0);
        Campaign storage campaign = campaignLists[_id - 1];
        require(
            campaign.duration > block.timestamp &&
                msg.sender != campaign.creator
        );
        campaign.fundRaise += _amount;
        contributorRecords[_id - 1][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev cancelContribution allows anyone to cancel their contribution
     * @param _id the id of the campaign
     */
    function cancelContribution(uint256 _id) external {
        Campaign storage campaign = campaignLists[_id - 1];
        require(
            campaign.duration > block.timestamp &&
                contributorRecords[_id - 1][msg.sender] != 0
        );
        uint amount = contributorRecords[_id - 1][msg.sender];
        contributorRecords[_id - 1][msg.sender] = 0;
        token.transfer(msg.sender, amount);
    }

    /**
     * @notice withdrawFunds allows the creator of the campaign to withdraw the funds
     * @param _id the id of the campaign
     */

    function withdrawFunds(uint256 _id) external {
        Campaign storage campaign = campaignLists[_id - 1];
        require(campaign.creator == msg.sender);
        require(
            campaign.duration <= block.timestamp &&
                token.getTokenPriceInUSD() * campaign.fundRaise >= campaign.goal
        );
        token.transfer(msg.sender, campaign.fundRaise);
        campaign.fundRaise = 0;
    }

    /**
     * @notice refund allows the contributors to get a refund if the campaign failed
     * @param _id the id of the campaign
     */
    function refund(uint256 _id) external {
        Campaign storage campaign = campaignLists[_id - 1];
        require(
            campaign.duration < block.timestamp &&
                token.getTokenPriceInUSD() * campaign.fundRaise < campaign.goal
        );
        require(contributorRecords[_id - 1][msg.sender] != 0);
        uint256 amount = contributorRecords[_id - 1][msg.sender];
        contributorRecords[_id - 1][msg.sender] = 0;
        require(token.transfer(msg.sender, amount), "refund fails");
    }

    /**
     * @notice getContribution returns the contribution of a contributor in USD
     * @param _id the id of the campaign
     * @param _contributor the address of the contributor
     */
    function getContribution(
        uint256 _id,
        address _contributor
    ) public view returns (uint256) {
        return
            contributorRecords[_id - 1][_contributor] *
            token.getTokenPriceInUSD();
    }

    /**
     * @notice getCampaign returns details about a campaign
     * @param _id the id of the campaign
     * @return remainingTime the time (in seconds) when the campaign ends
     * @return goal the goal of the campaign (in USD)
     * @return totalFunds total funds (in USD) raised by the campaign
     */
    function getCampaign(
        uint256 _id
    )
        external
        view
        returns (uint256 remainingTime, uint256 goal, uint256 totalFunds)
    {
        Campaign storage campaign = campaignLists[_id - 1];
        uint256 timeRemains = campaign.duration > block.timestamp
            ? campaign.duration - block.timestamp
            : 0;
        return (
            timeRemains,
            campaign.goal,
            token.getTokenPriceInUSD() * campaign.fundRaise
        );
    }
}
